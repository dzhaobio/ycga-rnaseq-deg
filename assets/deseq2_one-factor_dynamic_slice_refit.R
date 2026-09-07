#!/usr/bin/env Rscript

# https://gemini.google.com/app/eff99eaaa7dfc4e4

# module load R-bundle-Bioconductor/3.15-foss-2020b-R-4.2.0
.libPaths("/gpfs/gibbs/project/mane/dz288/R/4.2")

if (!requireNamespace("argparse", quietly = TRUE)) {
  install.packages("argparse", repos = "https://cloud.r-project.org/")
}
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  install.packages("openxlsx", repos = "https://cloud.r-project.org/")
}

library(argparse)

# ==============================================================================
# 1. DEFINE GTF DICTIONARY
# ==============================================================================
gtf_dict <- list(
  "hg38v27"            = "/home/dz288/tpl/DESeq2/hg38_gencode_v27_GTF_info.txt",
  "hg38v43"            = "/home/dz288/tpl/DESeq2/hg38_gencode_v43_GTF_info.txt",
  "mm10v15"            = "/home/dz288/tpl/DESeq2/mm10_gencode_v15_GTF_info.txt",
  "mm39vM35"           = "/home/dz288/tpl/DESeq2/mm39_gencode_vM35_GTF_info.txt",
  "mm10_ZsGreen"       = "/gpfs/gibbs/pi/ycga/mane.ycga/dz288/GenomeData/mm10_ZsGreen/gtf/mm10_WPRE_ZsGreen_GTF_info.txt",
  "dre_GRCz11"         = "/home/dz288/tpl/DESeq2/dre_GRCz11_ensembl_v201804_GTF_info.txt",
  "rn6v98"             = "/home/dz288/tpl/DESeq2/rn6_ensembl_v98_GTF_info.txt",
  "Scerevisiae_S288C"  = "/gpfs/ycga/work/mane/dz288/GenomeData/Scerevisiae_S288C/HISAT2/anno/GTF_table.exclCol3Exon.txt"
)
gtf_help_str <- paste(names(gtf_dict), collapse = ", ")

# ==============================================================================
# 2. COMMAND LINE ARGUMENTS CONFIGURATION
# ==============================================================================
parser <- ArgumentParser(
  prog = "deseq2_dynamic_slice_refit.R",
  formatter_class = "argparse.RawDescriptionHelpFormatter",
  description = "deseq2_dynamic_slice_refit.R: Advanced DESeq2 Pipeline with Dynamic Matrix Slicing and Independent Model Refitting."
)

parser$add_argument("-g", "--GTFinfo", required = TRUE, type = "character",
                    help = paste("Path to a GTFinfo file, OR an internal dictionary key. Supported keys:", gtf_help_str))
parser$add_argument("-m", "--gene_count_matrix", required = TRUE, type = "character", nargs = "+",
                    help = "Path to one or more count matrix CSV files.")
parser$add_argument("-s", "--sampleGroups", type = "character", default = NULL,
                    help = "Path to groups file OR direct group string (separated by ';'). Format per group: 'groupName:sample1,sample2' or 'groupName:sample1/sample2'. [Priority: Executed first, remaining samples passed to -r]")
parser$add_argument("-r", "--sample_group_regex", type = "character", default = NULL,
                    help = "Regex string to match group names from column headers. [Priority: Applied to samples NOT captured by -s]")
parser$add_argument("-c", "--comparisons", type = "character", default = NULL,
                    help = "Path to comparisons file OR comparison string. Format: 'A/B/C;D/E'. If Omitted, pairwise comparison across all groups will be performed.")
parser$add_argument("-e", "--exclude_outliers", type = "character", nargs = "*", default = NULL,
                    help = "Samples to exclude. Can be separated by spaces, commas, or slashes. Evaluated BEFORE grouping.")
parser$add_argument("-o", "--outputDir", type = "character", default = "DESeq2_analysis",
                    help = "Directory where output results will be saved. Default: DESeq2_analysis")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  parser$print_help()
  quit(status = 0)
}
parsed_args <- parser$parse_args()

if (is.null(parsed_args$sampleGroups) && is.null(parsed_args$sample_group_regex)) {
  stop("Error: You must provide at least one of -s/--sampleGroups or -r/--sample_group_regex to define groups.")
}

# ==============================================================================
# 3. DIRECTORY STRUCTURE SETUP & PACKAGES LOGGING
# ==============================================================================
library(dplyr)
library(vsn)
library(pheatmap)
library(RColorBrewer)
library(apeglm)
library(ggplot2)
library(ggrepel)
library(openxlsx)
library(DESeq2)

main_out_dir <- parsed_args$outputDir
share_out_dir <- file.path(main_out_dir, "DESeq2_output")
if (!dir.exists(main_out_dir)) dir.create(main_out_dir, recursive = TRUE)
if (!dir.exists(share_out_dir)) dir.create(share_out_dir, recursive = TRUE)

log_file <- file.path(main_out_dir, "run_command.log")
cmd_captured <- paste("Rscript deseq2_dynamic_slice_refit.R", paste(commandArgs(trailingOnly = TRUE), collapse = " "))
writeLines(c(paste("Timestamp:", Sys.time()), "Command Executed:", cmd_captured), log_file)

clean_name <- function(x) {
  if (is.null(x) || length(x) == 0) return(x)
  return(make.names(trimws(x)))
}

# ==============================================================================
# 4. DATA INGESTION & OUTLIER CLEANING
# ==============================================================================
gtf_path <- parsed_args$GTFinfo
if (gtf_path %in% names(gtf_dict)) {
  gtf_path <- gtf_dict[[gtf_path]]
}
if (!file.exists(gtf_path)) {
  stop(paste("Error: Specified GTFinfo file or reference key not found:", gtf_path))
}
GTFinfo <- read.table(file = gtf_path, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
GTFinfo$GeneVer_clean <- make.names(GTFinfo$GeneVer)

countData0 <- NULL
for (matrix_file in parsed_args$gene_count_matrix) {
  tmp_counts <- as.data.frame(read.csv(matrix_file, row.names = "gene_id", check.names = FALSE))
  if (is.null(countData0)) {
    countData0 <- tmp_counts
  } else {
    shared_genes <- intersect(rownames(countData0), rownames(tmp_counts))
    countData0 <- cbind(countData0[shared_genes, , drop = FALSE], tmp_counts[shared_genes, , drop = FALSE])
  }
}
colnames(countData0) <- make.names(colnames(countData0))

if (!is.null(parsed_args$exclude_outliers) && length(parsed_args$exclude_outliers) > 0) {
  raw_outliers <- unlist(strsplit(parsed_args$exclude_outliers, "[,/\\s+]+"))
  outliers_to_remove <- sapply(raw_outliers, clean_name, USE.NAMES = FALSE)
  outliers_to_remove <- outliers_to_remove[outliers_to_remove != ""]
  present_outliers <- outliers_to_remove[outliers_to_remove %in% colnames(countData0)]
  if (length(present_outliers) > 0) {
    countData0 <- countData0[, !colnames(countData0) %in% present_outliers, drop = FALSE]
    cat("Successfully excluded outlier samples prior to grouping:", paste(present_outliers, collapse = ", "), "\n")
  }
}

# ==============================================================================
# 5. SAMPLE GROUPING MAP CONSTRUCTION (Tracking exact group mappings)
# ==============================================================================
group_map <- list()
append_to_group <- function(g_name, s_vector) {
  g_name <- clean_name(g_name)
  s_vector <- sapply(s_vector, clean_name, USE.NAMES = FALSE)
  s_vector <- s_vector[s_vector %in% colnames(countData0)]
  if (length(s_vector) == 0) return()
  if (g_name %in% names(group_map)) {
    cat("Notice: Group '", g_name, "' already exists. Merging additional samples.\n", sep="")
    group_map[[g_name]] <<- union(group_map[[g_name]], s_vector)
  } else {
    group_map[[g_name]] <<- unique(s_vector)
  }
}

samples_captured_by_s <- c()
if (!is.null(parsed_args$sampleGroups)) {
  s_content <- parsed_args$sampleGroups
  if (file.exists(s_content)) s_content <- paste(readLines(s_content), collapse = ";")
  group_blocks <- unlist(strsplit(s_content, ";+"))
  for (block in group_blocks) {
    if (trimws(block) == "") next
    parts <- unlist(strsplit(block, ":"))
    if (length(parts) < 2) next
    g_name <- trimws(parts[1])
    s_names <- unlist(strsplit(trimws(parts[2]), "[,/]+"))
    s_names <- sapply(s_names, clean_name, USE.NAMES = FALSE)
    append_to_group(g_name, s_names)
    samples_captured_by_s <- union(samples_captured_by_s, s_names[s_names %in% colnames(countData0)])
  }
}

if (!is.null(parsed_args$sample_group_regex)) {
  remaining_samples <- setdiff(colnames(countData0), samples_captured_by_s)
  if (length(remaining_samples) > 0) {
    regex_matches <- regexpr(parsed_args$sample_group_regex, remaining_samples)
    matched_groups <- regmatches(remaining_samples, regex_matches)
    valid_indices <- which(regex_matches != -1)
    if (length(valid_indices) > 0) {
      for (idx in valid_indices) {
        append_to_group(matched_groups[idx], remaining_samples[idx])
      }
    }
  }
}

cat("\nFinal Sample Grouping Table:\n")
for (g in names(group_map)) {
  cat("  Group [", g, "]: ", paste(group_map[[g]], collapse=", "), " (n=", length(group_map[[g]]), ")\n", sep="")
}

# Find all unique samples involved globally across any group for global QC plots
all_active_samples <- unique(unlist(group_map))
global_countData <- countData0[, all_active_samples, drop = FALSE]

sharedRowNames <- intersect(rownames(global_countData), GTFinfo$GeneVer_clean)
GTFinfo <- GTFinfo[match(sharedRowNames, GTFinfo$GeneVer_clean), ]
rownames(GTFinfo) <- GTFinfo$GeneVer_clean
global_countData <- global_countData[sharedRowNames, , drop = FALSE]

# ==============================================================================
# 6. GLOBAL QUALITY CONTROL (Based on unique raw data pool)
# ==============================================================================
global_conditions <- sapply(all_active_samples, function(s) {
  for (g in names(group_map)) {
    if (s %in% group_map[[g]]) return(g)
  }
  return("Unknown")
})

global_colData <- data.frame(row.names = all_active_samples, sampleCondition = factor(global_conditions))
dds_global <- DESeqDataSetFromMatrix(countData = global_countData, colData = global_colData, design = ~ sampleCondition)
dds_global <- estimateSizeFactors(dds_global)

pdf(file.path(share_out_dir, "gene_count_matrix.pdf"), width = max(6, length(all_active_samples)*0.25), height = 8)
par(mar = c(6, 4, 4, 2) + 0.1)
barplot(colSums(global_countData), main = "Raw Read Counts per Active Sample", las = 2, cex.names = 0.7)
grid(nx = NA, ny = NULL)
dev.off()

vsd_global <- vst(dds_global, blind = TRUE)
pdf(file.path(share_out_dir, "global_samples_PCA.pdf"), width = 8, height = 7)
print(plotPCA(vsd_global, intgroup = "sampleCondition") + geom_text_repel(aes(label = name), size = 3) + theme_bw() + ggtitle("Global QC PCA (All Active Samples)"))
dev.off()

sampleDists <- dist(t(assay(vsd_global)))
colors <- colorRampPalette(rev(brewer.pal(9, "Blues")))(255)
pheatmap(as.matrix(sampleDists), clustering_distance_rows = sampleDists, clustering_distance_cols = sampleDists, 
         col = colors, filename = file.path(main_out_dir, "global_sample_clustering.pdf"))

# ==============================================================================
# 7. PARSING COMPARISONS
# ==============================================================================
all_detected_groups <- names(group_map)
comp_list <- list()

if (!is.null(parsed_args$comparisons)) {
  c_content <- parsed_args$comparisons
  if (file.exists(c_content)) c_content <- paste(readLines(c_content), collapse = ";")
  comp_blocks <- unlist(strsplit(c_content, ";+"))
  for (block in comp_blocks) {
    if (trimws(block) == "") next
    raw_groups <- unlist(strsplit(trimws(block), "/+"))
    cleaned_groups <- sapply(raw_groups, clean_name, USE.NAMES = FALSE)
    cleaned_groups <- cleaned_groups[cleaned_groups %in% all_detected_groups]
    if (length(cleaned_groups) >= 2) {
      dir_title <- paste(cleaned_groups, collapse = "_vs_")
      comp_list[[dir_title]] <- cleaned_groups
    }
  }
} else {
  if (length(all_detected_groups) >= 2) {
    pairwise_combinations <- combn(all_detected_groups, 2)
    for (col_idx in seq_len(ncol(pairwise_combinations))) {
      gA <- pairwise_combinations[1, col_idx]
      gB <- pairwise_combinations[2, col_idx]
      dir_title <- paste0(gA, "_vs_", gB)
      comp_list[[dir_title]] <- c(gA, gB)
    }
  }
}

# ==============================================================================
# 8. COMPARTMENT ANALYSIS LOOP (RIGOROUS SLICE & REFIT ENGINE)
# ==============================================================================
for (sub_dir_name in names(comp_list)) {
  target_groups <- comp_list[[sub_dir_name]]
  # sub_dir_path <- file.path(main_out_dir, sub_dir_name)
  sub_dir_path <- file.path(share_out_dir, sub_dir_name) #7/18/26 mv DESeq2 results to DESeq2_output
  if (!dir.exists(sub_dir_path)) dir.create(sub_dir_path, recursive = TRUE)
  
  cat("\n======================================================================")
  cat("\n[Refit Mode] Entering Compartment: ", sub_dir_name, "\n")
  
  # Step 1: Extract ONLY raw samples associated with target groups for this slice
  slice_samples <- c()
  slice_conditions <- c()
  slice_source_cols <- c()
  
  for (g_name in target_groups) {
    for (s_name in group_map[[g_name]]) {
      pseudo_col <- paste0(g_name, "___", s_name)
      slice_samples <- c(slice_samples, pseudo_col)
      slice_conditions <- c(slice_conditions, g_name)
      slice_source_cols <- c(slice_source_cols, s_name)
    }
  }
  
  slice_countData <- countData0[sharedRowNames, slice_source_cols, drop = FALSE]
  colnames(slice_countData) <- slice_samples
  
  slice_colData <- data.frame(
    row.names = slice_samples,
    sampleCondition = factor(slice_conditions, levels = target_groups),
    originalSample = slice_source_cols
  )
  
  cat("  Fitting localized DESeq2 model for samples:", paste(unique(slice_source_cols), collapse=", "), "\n")
  dds_slice <- DESeqDataSetFromMatrix(countData = slice_countData, colData = slice_colData, design = ~ sampleCondition)
  dds_slice <- DESeq(dds_slice)
  
  slice_normcnts <- counts(dds_slice, normalized = TRUE)
  slice_rld <- rlogTransformation(dds_slice, blind = FALSE)
  
  internal_pairs <- combn(target_groups, 2)
  
  # Pass 1: Unfiltered Tables
  for (p_idx in seq_len(ncol(internal_pairs))) {
    gA <- internal_pairs[1, p_idx]
    gB <- internal_pairs[2, p_idx]
    
    res <- results(dds_slice, contrast = c("sampleCondition", gA, gB))
    res_df <- as.data.frame(res)
    res_df$genes <- rownames(res_df)
    
    cols_gA_gB <- rownames(slice_colData)[slice_colData$sampleCondition %in% c(gA, gB)]
    pair_norm_counts <- slice_normcnts[, cols_gA_gB, drop = FALSE]
    colnames(pair_norm_counts) <- slice_colData[cols_gA_gB, "originalSample"]
    
    full_table_data <- cbind(GTFinfo[rownames(res_df), ], res_df, pair_norm_counts)
    full_table_path <- file.path(sub_dir_path, paste0(gA, "_vs_", gB, ".all_genes.fulltable.xlsx"))
    openxlsx::write.xlsx(full_table_data, file = full_table_path, rowNames = FALSE)
  }
  
  # Pass 2: Thresholding and Plots
  for (FCcutoff in c(1, 2)) {
    padjCutoff <- 0.05
    DEGCriteria <- paste0("padj", padjCutoff, "_FC", FCcutoff)
    
    local_sig_mat <- matrix(data = 0, nrow = length(target_groups), ncol = length(target_groups), dimnames = list(target_groups, target_groups))
    all_genes_with_degs <- c()
    
    for (p_idx in seq_len(ncol(internal_pairs))) {
      gA <- internal_pairs[1, p_idx]
      gB <- internal_pairs[2, p_idx]
      
      full_table_path <- file.path(sub_dir_path, paste0(gA, "_vs_", gB, ".all_genes.fulltable.xlsx"))
      full_table_data <- openxlsx::read.xlsx(full_table_path)
      
      deg_table_data <- full_table_data %>% filter(padj <= padjCutoff) %>% filter(abs(log2FoldChange) >= log2(FCcutoff))
      selectGenes <- deg_table_data$GeneVer_clean
      local_sig_mat[gA, gB] <- length(selectGenes)
      all_genes_with_degs <- union(all_genes_with_degs, selectGenes)
      
      if (length(selectGenes) > 0) {
        deg_table_path <- file.path(sub_dir_path, paste0(gA, "_vs_", gB, "_", DEGCriteria, ".xlsx"))
        openxlsx::write.xlsx(deg_table_data, file = deg_table_path, rowNames = FALSE)
        
        # --------------------------------------------------------------------
        # VOLCANO PLOT: Y-axis is -log10(pvalue), Coloring is based on padj!
        # --------------------------------------------------------------------
        volcano_data <- full_table_data %>%
          mutate(Expression = case_when(padj <= padjCutoff & log2FoldChange >= log2(FCcutoff) ~ "Up-regulated",
                                        padj <= padjCutoff & log2FoldChange <= -log2(FCcutoff) ~ "Down-regulated",
                                        TRUE ~ "Not Significant"))
        
        top10_genes <- volcano_data %>% filter(Expression != "Not Significant") %>% arrange(padj, pvalue) %>% head(10)
        
        # NOTE: Mapping y to -log10(pvalue) and removing all vertical/horizontal lines
        volcano_plot <- ggplot(volcano_data, aes(x = log2FoldChange, y = -log10(pvalue))) +
          geom_point(aes(color = Expression), alpha = 0.7, size = 1.5) +
          scale_color_manual(values = c("Down-regulated" = "green", "Up-regulated" = "red", "Not Significant" = "grey")) +
          theme_bw() +
          labs(title = paste("Volcano Plot:", gA, "vs", gB, paste0("(FC=", FCcutoff, ")")), 
               x = "log2(Fold Change)", 
               y = "-log10(p-value)")
        
        if (nrow(top10_genes) > 0) {
          label_col <- if("GeneName" %in% colnames(top10_genes)) "GeneName" else "GeneVer_clean"
          volcano_plot <- volcano_plot + geom_text_repel(data = top10_genes, aes(label = .data[[label_col]]), size = 3.5, max.overlaps = 15, box.padding = 0.5)
        }
        ggsave(filename = file.path(sub_dir_path, paste0(gA, "_vs_", gB, "_", DEGCriteria, ".volcano_plot.pdf")), plot = volcano_plot, width = 7, height = 6)
      }
    }
    
    # --------------------------------------------------------------------
    # SIGNIFICANT GENES MATRIX: Title adjusted to "DEGs Count Matrix"
    # --------------------------------------------------------------------
    pheatmap(local_sig_mat, col = colors, scale = "none", cluster_rows = FALSE, cluster_cols = FALSE,
             display_numbers = TRUE, number_format = "%.0f", fontsize_number = 16, number_color = "black",
             main = paste0("DEGs Count Matrix:\n", DEGCriteria),
             filename = file.path(sub_dir_path, paste0("SignificantGenesMatrix_", DEGCriteria, ".pdf")))
    
    # --------------------------------------------------------------------
    # LOCAL COMPARTMENT HEATMAP: Title adjusted to "HeatMap of DEGs"
    # --------------------------------------------------------------------
    if (length(all_genes_with_degs) > 1) {
      heatmap_mat <- assay(slice_rld)[all_genes_with_degs, slice_samples, drop = FALSE]
      colnames(heatmap_mat) <- slice_colData$originalSample
      
      annotation_df <- data.frame(row.names = slice_colData$originalSample, Condition = slice_colData$sampleCondition)
      pheatmap(heatmap_mat, cluster_rows = TRUE, show_rownames = FALSE, cluster_cols = TRUE, scale = "row", 
               main = paste0("HeatMap of DEGs (n=", length(all_genes_with_degs), ")\nCriteria: ", DEGCriteria), 
               annotation_col = annotation_df, 
               filename = file.path(sub_dir_path, paste0("Heatmap_Combined_DEGs_", DEGCriteria, ".pdf")), 
               width = max(6, length(slice_samples) * 0.35 + 3))
    }
  }
}

# ==============================================================================
# 9. ENVIRONMENTAL FOOTPRINT RECOVERY
# ==============================================================================
writeLines(capture.output(sessionInfo()), file.path(share_out_dir, "sessionInfo.txt"))
save.image(file.path(main_out_dir, "deseq2_dynamic_slice_refit.RData"))
cat("\nPipeline execution complete! Every comparison group was independently refitted successfully.\n")

