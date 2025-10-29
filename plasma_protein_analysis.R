# ================================================================================
# Plasma Protein Biostatistical Analysis
# ================================================================================
# Comprehensive statistical analysis of plasma-derived therapeutics
# Target: CSL Behring Data Scientist Laboratory Position
# Author: [Your Name]
# ================================================================================

# Required Libraries
# ================================================================================
library(tidyverse)      # Data manipulation and visualization
library(ggplot2)        # Advanced plotting
library(gridExtra)      # Multiple plots
library(pROC)           # ROC curve analysis
library(car)            # Regression diagnostics
library(MASS)           # Statistical functions
library(broom)          # Tidy statistical output
library(scales)         # Pretty breaks and labels

# Optional libraries for advanced analysis
# library(caret)        # Machine learning
# library(nlme)         # Non-linear mixed effects
# library(survival)     # Survival analysis

# ================================================================================
# 1. DATA GENERATION & PREPARATION
# ================================================================================

generate_plasma_protein_data <- function(n_samples = 1000) {
  #' Generate synthetic plasma protein production data
  #' Simulates CSL Behring manufacturing process
  #' 
  #' @param n_samples Number of samples to generate
  #' @return DataFrame with protein manufacturing data
  
  set.seed(42)
  
  # Production parameters
  batches <- paste0("BATCH-", sprintf("%04d", 1:n_samples))
  dates <- seq(as.Date("2023-01-01"), by = "day", length.out = n_samples)
  
  # Manufacturing sites
  sites <- sample(c("Marburg", "Bern", "Kankakee"), n_samples, 
                 replace = TRUE, prob = c(0.5, 0.3, 0.2))
  
  # Product types (CSL Behring portfolio)
  products <- sample(
    c("Factor_VIII", "Immunoglobulin_G", "Albumin", "Alpha1_Antitrypsin"),
    n_samples, replace = TRUE, prob = c(0.25, 0.35, 0.25, 0.15)
  )
  
  # Key quality attributes
  # Protein concentration (mg/mL)
  target_concentration <- 50
  concentration <- rnorm(n_samples, mean = target_concentration, sd = 2.5)
  
  # Purity (%) - higher is better
  purity <- rbeta(n_samples, shape1 = 98, shape2 = 2) * 100
  purity <- pmax(pmin(purity, 100), 90)  # Constrain to 90-100%
  
  # Aggregate content (%) - lower is better
  aggregates <- rexp(n_samples, rate = 0.5)
  aggregates <- pmin(aggregates, 10)  # Cap at 10%
  
  # Viral clearance log reduction value (LRV)
  viral_clearance <- rnorm(n_samples, mean = 12, sd = 1.5)
  viral_clearance <- pmax(viral_clearance, 8)  # Minimum LRV of 8
  
  # Process parameters
  ph <- rnorm(n_samples, mean = 7.2, sd = 0.15)
  temperature_C <- rnorm(n_samples, mean = 4, sd = 0.5)
  conductivity_mS <- rnorm(n_samples, mean = 8.5, sd = 0.8)
  
  # Yield (kg protein per batch)
  base_yield <- 25
  yield <- rnorm(n_samples, mean = base_yield, sd = 3)
  # Yield correlates with purity and inversely with aggregates
  yield <- yield + 0.3 * (purity - mean(purity)) - 0.5 * (aggregates - mean(aggregates))
  yield <- pmax(yield, 10)  # Minimum yield
  
  # Quality outcome: PASS/FAIL based on specifications
  qc_pass <- (concentration >= 45 & concentration <= 55) &
             (purity >= 95) &
             (aggregates <= 5) &
             (viral_clearance >= 10) &
             (ph >= 6.9 & ph <= 7.5)
  
  # Create dataframe
  data <- tibble(
    Batch_ID = batches,
    Date = dates,
    Site = sites,
    Product = products,
    Concentration_mg_mL = concentration,
    Purity_Percent = purity,
    Aggregates_Percent = aggregates,
    Viral_Clearance_LRV = viral_clearance,
    pH = ph,
    Temperature_C = temperature_C,
    Conductivity_mS = conductivity_mS,
    Yield_kg = yield,
    QC_Status = ifelse(qc_pass, "PASS", "FAIL")
  )
  
  cat("✓ Generated", n_samples, "plasma protein production samples\n")
  cat("✓ Products:", length(unique(products)), "types\n")
  cat("✓ Manufacturing sites:", length(unique(sites)), "locations\n")
  cat("✓ QC Pass Rate:", sprintf("%.1f%%", mean(qc_pass) * 100), "\n\n")
  
  return(data)
}


# ================================================================================
# 2. EXPLORATORY DATA ANALYSIS
# ================================================================================

exploratory_analysis <- function(data) {
  #' Comprehensive exploratory data analysis
  #' 
  #' @param data Plasma protein production data
  
  cat("="*80, "\n")
  cat("EXPLORATORY DATA ANALYSIS\n")
  cat("="*80, "\n\n")
  
  # Summary statistics
  cat("SUMMARY STATISTICS\n")
  cat("-"*80, "\n")
  summary_stats <- data %>%
    select(Concentration_mg_mL, Purity_Percent, Aggregates_Percent, 
           Viral_Clearance_LRV, Yield_kg) %>%
    summary()
  print(summary_stats)
  
  # QC Status by Product
  cat("\n\nQC STATUS BY PRODUCT\n")
  cat("-"*80, "\n")
  qc_summary <- data %>%
    group_by(Product, QC_Status) %>%
    summarise(Count = n(), .groups = "drop") %>%
    pivot_wider(names_from = QC_Status, values_from = Count, values_fill = 0) %>%
    mutate(Pass_Rate = PASS / (PASS + FAIL) * 100)
  print(qc_summary)
  
  # QC Status by Site
  cat("\n\nQC STATUS BY MANUFACTURING SITE\n")
  cat("-"*80, "\n")
  site_summary <- data %>%
    group_by(Site, QC_Status) %>%
    summarise(Count = n(), .groups = "drop") %>%
    pivot_wider(names_from = QC_Status, values_from = Count, values_fill = 0) %>%
    mutate(Pass_Rate = PASS / (PASS + FAIL) * 100)
  print(site_summary)
  
  cat("\n")
}


# ================================================================================
# 3. STATISTICAL PROCESS CONTROL
# ================================================================================

plot_control_chart <- function(data, parameter, title = NULL) {
  #' Shewhart control chart for process monitoring
  #' 
  #' @param data Plasma protein data
  #' @param parameter Column name to plot
  #' @param title Optional plot title
  
  values <- data[[parameter]]
  
  # Calculate control limits
  mean_value <- mean(values, na.rm = TRUE)
  sd_value <- sd(values, na.rm = TRUE)
  
  ucl <- mean_value + 3 * sd_value  # Upper Control Limit
  lcl <- mean_value - 3 * sd_value  # Lower Control Limit
  uwl <- mean_value + 2 * sd_value  # Upper Warning Limit
  lwl <- mean_value - 2 * sd_value  # Lower Warning Limit
  
  # Identify out-of-control points
  data$OOC <- values > ucl | values < lcl
  
  # Create plot
  p <- ggplot(data, aes(x = seq_along(values), y = values)) +
    geom_line(color = "steelblue", size = 0.5, alpha = 0.7) +
    geom_point(aes(color = OOC), size = 2) +
    scale_color_manual(values = c("FALSE" = "steelblue", "TRUE" = "red"),
                      labels = c("In Control", "Out of Control"),
                      name = "Status") +
    
    # Control limits
    geom_hline(yintercept = mean_value, color = "green", 
               linetype = "solid", size = 1) +
    geom_hline(yintercept = c(ucl, lcl), color = "red", 
               linetype = "dashed", size = 1) +
    geom_hline(yintercept = c(uwl, lwl), color = "orange", 
               linetype = "dotted", size = 0.8, alpha = 0.7) +
    
    # Labels
    annotate("text", x = length(values) * 0.95, y = mean_value, 
             label = sprintf("μ = %.2f", mean_value), hjust = 1, vjust = -1) +
    annotate("text", x = length(values) * 0.95, y = ucl, 
             label = sprintf("UCL = %.2f", ucl), hjust = 1, vjust = -1) +
    annotate("text", x = length(values) * 0.95, y = lcl, 
             label = sprintf("LCL = %.2f", lcl), hjust = 1, vjust = 1.5) +
    
    # Theme
    labs(
      title = ifelse(is.null(title), 
                    paste("Control Chart:", parameter), 
                    title),
      x = "Sample Number",
      y = parameter
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "top",
      panel.grid.minor = element_blank()
    )
  
  print(p)
  
  # Statistics
  ooc_count <- sum(data$OOC, na.rm = TRUE)
  ooc_rate <- mean(data$OOC, na.rm = TRUE) * 100
  
  cat("\n📊 Control Chart Statistics:\n")
  cat(sprintf("   Mean: %.3f\n", mean_value))
  cat(sprintf("   Std Dev: %.3f\n", sd_value))
  cat(sprintf("   UCL: %.3f | LCL: %.3f\n", ucl, lcl))
  cat(sprintf("   Out-of-control points: %d (%.2f%%)\n\n", ooc_count, ooc_rate))
  
  return(list(mean = mean_value, sd = sd_value, ucl = ucl, lcl = lcl))
}


# ================================================================================
# 4. COMPARATIVE ANALYSIS
# ================================================================================

compare_sites <- function(data) {
  #' Compare quality metrics across manufacturing sites
  #' ANOVA and post-hoc analysis
  #' 
  #' @param data Plasma protein data
  
  cat("="*80, "\n")
  cat("COMPARATIVE ANALYSIS: MANUFACTURING SITES\n")
  cat("="*80, "\n\n")
  
  # ANOVA for Yield
  cat("1. ANALYSIS OF VARIANCE - Yield by Site\n")
  cat("-"*80, "\n")
  
  yield_aov <- aov(Yield_kg ~ Site, data = data)
  print(summary(yield_aov))
  
  # Post-hoc test (Tukey HSD)
  cat("\n2. POST-HOC ANALYSIS (Tukey HSD)\n")
  cat("-"*80, "\n")
  tukey_result <- TukeyHSD(yield_aov)
  print(tukey_result)
  
  # Boxplot comparison
  p1 <- ggplot(data, aes(x = Site, y = Yield_kg, fill = Site)) +
    geom_boxplot(alpha = 0.7, outlier.shape = 21) +
    stat_summary(fun = mean, geom = "point", shape = 23, 
                size = 3, color = "red", fill = "red") +
    labs(
      title = "Yield Comparison Across Manufacturing Sites",
      subtitle = "Red diamond = mean",
      x = "Manufacturing Site",
      y = "Yield (kg)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "none"
    ) +
    scale_fill_brewer(palette = "Set2")
  
  print(p1)
  
  # Violin plot for purity
  p2 <- ggplot(data, aes(x = Site, y = Purity_Percent, fill = Site)) +
    geom_violin(alpha = 0.7, trim = FALSE) +
    geom_boxplot(width = 0.2, alpha = 0.5, outlier.shape = NA) +
    labs(
      title = "Purity Distribution by Site",
      x = "Manufacturing Site",
      y = "Purity (%)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "none"
    ) +
    scale_fill_brewer(palette = "Set2")
  
  print(p2)
  
  cat("\n")
}


# ================================================================================
# 5. CORRELATION & MULTIVARIATE ANALYSIS
# ================================================================================

correlation_analysis <- function(data) {
  #' Analyze correlations between quality parameters
  #' 
  #' @param data Plasma protein data
  
  cat("="*80, "\n")
  cat("CORRELATION ANALYSIS\n")
  cat("="*80, "\n\n")
  
  # Select numeric variables
  numeric_vars <- data %>%
    select(Concentration_mg_mL, Purity_Percent, Aggregates_Percent,
           Viral_Clearance_LRV, pH, Temperature_C, Conductivity_mS, Yield_kg)
  
  # Correlation matrix
  cor_matrix <- cor(numeric_vars, use = "complete.obs")
  
  cat("CORRELATION MATRIX\n")
  cat("-"*80, "\n")
  print(round(cor_matrix, 3))
  
  # Visualize correlation matrix
  cor_data <- as.data.frame(as.table(cor_matrix))
  names(cor_data) <- c("Var1", "Var2", "Correlation")
  
  p <- ggplot(cor_data, aes(x = Var1, y = Var2, fill = Correlation)) +
    geom_tile(color = "white") +
    geom_text(aes(label = sprintf("%.2f", Correlation)), 
             size = 3, color = "white") +
    scale_fill_gradient2(
      low = "blue", mid = "white", high = "red",
      midpoint = 0, limit = c(-1, 1),
      name = "Pearson\nCorrelation"
    ) +
    labs(
      title = "Correlation Matrix Heatmap",
      subtitle = "Quality Parameters and Process Variables"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.title = element_blank(),
      plot.title = element_text(face = "bold", size = 14)
    )
  
  print(p)
  
  cat("\n")
}


# ================================================================================
# 6. PREDICTIVE MODELING
# ================================================================================

build_yield_model <- function(data) {
  #' Multiple linear regression to predict protein yield
  #' 
  #' @param data Plasma protein data
  
  cat("="*80, "\n")
  cat("PREDICTIVE MODELING: YIELD PREDICTION\n")
  cat("="*80, "\n\n")
  
  # Build model
  model <- lm(Yield_kg ~ Purity_Percent + Aggregates_Percent + 
               Viral_Clearance_LRV + pH + Temperature_C + Conductivity_mS,
              data = data)
  
  # Model summary
  cat("MULTIPLE LINEAR REGRESSION SUMMARY\n")
  cat("-"*80, "\n")
  print(summary(model))
  
  # Model diagnostics
  cat("\n\nMODEL DIAGNOSTICS\n")
  cat("-"*80, "\n")
  
  # Check for multicollinearity (VIF)
  vif_values <- vif(model)
  cat("\nVariance Inflation Factors (VIF):\n")
  print(round(vif_values, 2))
  cat("(VIF > 5 indicates multicollinearity concerns)\n")
  
  # Residual plots
  par(mfrow = c(2, 2))
  plot(model, main = "Regression Diagnostics")
  par(mfrow = c(1, 1))
  
  # Predicted vs Actual
  data$Predicted_Yield <- predict(model, data)
  
  p <- ggplot(data, aes(x = Yield_kg, y = Predicted_Yield)) +
    geom_point(alpha = 0.4, color = "steelblue") +
    geom_abline(intercept = 0, slope = 1, color = "red", 
               linetype = "dashed", size = 1) +
    labs(
      title = "Predicted vs Actual Yield",
      subtitle = sprintf("R² = %.3f, RMSE = %.2f kg", 
                        summary(model)$r.squared,
                        sqrt(mean(model$residuals^2))),
      x = "Actual Yield (kg)",
      y = "Predicted Yield (kg)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  
  print(p)
  
  cat("\n")
  return(model)
}


# ================================================================================
# 7. QUALITY RISK ASSESSMENT
# ================================================================================

logistic_qc_model <- function(data) {
  #' Logistic regression to predict QC failure risk
  #' 
  #' @param data Plasma protein data
  
  cat("="*80, "\n")
  cat("QUALITY RISK ASSESSMENT: QC FAILURE PREDICTION\n")
  cat("="*80, "\n\n")
  
  # Convert QC_Status to binary
  data$QC_Binary <- ifelse(data$QC_Status == "PASS", 1, 0)
  
  # Build logistic regression model
  model <- glm(QC_Binary ~ Purity_Percent + Aggregates_Percent + 
                Viral_Clearance_LRV + pH,
               data = data, family = binomial(link = "logit"))
  
  # Model summary
  cat("LOGISTIC REGRESSION SUMMARY\n")
  cat("-"*80, "\n")
  print(summary(model))
  
  # Odds ratios
  cat("\n\nODDS RATIOS\n")
  cat("-"*80, "\n")
  odds_ratios <- exp(coef(model))
  print(round(odds_ratios, 3))
  
  # ROC curve
  data$QC_Probability <- predict(model, type = "response")
  roc_obj <- roc(data$QC_Binary, data$QC_Probability, quiet = TRUE)
  
  cat("\n\nMODEL PERFORMANCE\n")
  cat("-"*80, "\n")
  cat(sprintf("AUC (Area Under Curve): %.4f\n", auc(roc_obj)))
  
  # Plot ROC curve
  plot(roc_obj, main = "ROC Curve: QC Pass/Fail Prediction",
       col = "steelblue", lwd = 2, print.auc = TRUE)
  
  cat("\n")
  return(model)
}


# ================================================================================
# 8. TREND ANALYSIS
# ================================================================================

temporal_trend_analysis <- function(data) {
  #' Analyze trends over time for quality parameters
  #' 
  #' @param data Plasma protein data
  
  cat("="*80, "\n")
  cat("TEMPORAL TREND ANALYSIS\n")
  cat("="*80, "\n\n")
  
  # Moving average
  data <- data %>%
    arrange(Date) %>%
    mutate(
      Purity_MA7 = zoo::rollmean(Purity_Percent, k = 7, fill = NA, align = "right"),
      Yield_MA7 = zoo::rollmean(Yield_kg, k = 7, fill = NA, align = "right")
    )
  
  # Trend plot
  p1 <- ggplot(data, aes(x = Date)) +
    geom_point(aes(y = Purity_Percent), alpha = 0.3, color = "gray50", size = 1) +
    geom_line(aes(y = Purity_MA7), color = "steelblue", size = 1) +
    geom_smooth(aes(y = Purity_Percent), method = "loess", 
               color = "red", size = 0.8, se = TRUE, alpha = 0.2) +
    labs(
      title = "Purity Trend Over Time",
      subtitle = "Blue line: 7-day moving average | Red line: LOESS smoothing",
      x = "Date",
      y = "Purity (%)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  
  print(p1)
  
  p2 <- ggplot(data, aes(x = Date)) +
    geom_point(aes(y = Yield_kg), alpha = 0.3, color = "gray50", size = 1) +
    geom_line(aes(y = Yield_MA7), color = "darkgreen", size = 1) +
    geom_smooth(aes(y = Yield_kg), method = "loess", 
               color = "orange", size = 0.8, se = TRUE, alpha = 0.2) +
    labs(
      title = "Yield Trend Over Time",
      subtitle = "Green line: 7-day moving average | Orange line: LOESS smoothing",
      x = "Date",
      y = "Yield (kg)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  
  print(p2)
  
  cat("\n")
}


# ================================================================================
# MAIN EXECUTION
# ================================================================================

main <- function() {
  #' Main execution function demonstrating all analyses
  
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════════════╗\n")
  cat("║        PLASMA PROTEIN BIOSTATISTICAL ANALYSIS PIPELINE                ║\n")
  cat("║        CSL Behring Marburg - Data Scientist Position                  ║\n")
  cat("╚════════════════════════════════════════════════════════════════════════╝\n\n")
  
  # Generate data
  data <- generate_plasma_protein_data(n_samples = 1000)
  
  # Run analyses
  exploratory_analysis(data)
  
  cat("\n"); Sys.sleep(1)
  plot_control_chart(data, "Concentration_mg_mL", 
                    "SPC: Protein Concentration")
  
  cat("\n"); Sys.sleep(1)
  compare_sites(data)
  
  cat("\n"); Sys.sleep(1)
  correlation_analysis(data)
  
  cat("\n"); Sys.sleep(1)
  yield_model <- build_yield_model(data)
  
  cat("\n"); Sys.sleep(1)
  qc_model <- logistic_qc_model(data)
  
  cat("\n"); Sys.sleep(1)
  temporal_trend_analysis(data)
  
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════════════╗\n")
  cat("║                      ✓ ANALYSIS COMPLETE                               ║\n")
  cat("╚════════════════════════════════════════════════════════════════════════╝\n")
  cat("\nKey Capabilities Demonstrated:\n")
  cat("  ✓ Statistical Process Control (SPC)\n")
  cat("  ✓ ANOVA & Post-hoc Testing\n")
  cat("  ✓ Correlation & Multivariate Analysis\n")
  cat("  ✓ Multiple Linear Regression\n")
  cat("  ✓ Logistic Regression & ROC Analysis\n")
  cat("  ✓ Time Series & Trend Analysis\n")
  cat("  ✓ Data Visualization (ggplot2)\n")
  cat("  ✓ GMP/Regulatory Statistics\n\n")
}

# Run the analysis
main()
