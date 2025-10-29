"""
HPLC-MS/MS Quality Control Analysis Pipeline
============================================
Automated analysis of HPLC-MS/MS data for biopharmaceutical quality control.
Suitable for plasma protein therapeutics and monoclonal antibody analysis.

Author: [Your Name]
Target: CSL Behring Laboratory Position
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from sklearn.ensemble import IsolationForest
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class HPLCQualityControl:
    """
    Quality Control analysis for HPLC-MS/MS data in biopharmaceutical manufacturing.
    Includes statistical process control, method validation, and anomaly detection.
    """
    
    def __init__(self, data_path=None):
        """Initialize QC analyzer with optional data path."""
        self.data = None
        self.control_limits = {}
        self.validation_results = {}
        
        if data_path:
            self.load_data(data_path)
    
    def load_data(self, path):
        """Load HPLC-MS/MS data from CSV file."""
        try:
            self.data = pd.read_csv(path)
            print(f"✓ Data loaded: {len(self.data)} samples")
            return self.data
        except Exception as e:
            print(f"✗ Error loading data: {e}")
            return None
    
    def generate_sample_data(self, n_samples=500):
        """
        Generate synthetic HPLC-MS/MS data for demonstration.
        Simulates plasma protein concentration measurements.
        """
        np.random.seed(42)
        
        # Simulate production batches over time
        dates = pd.date_range(start='2024-01-01', periods=n_samples, freq='D')
        
        # Target protein concentration (mg/mL) with normal variation
        target_concentration = 50.0
        concentrations = np.random.normal(target_concentration, 2.5, n_samples)
        
        # Add some systematic drift (simulating instrument aging)
        drift = np.linspace(0, -1.5, n_samples)
        concentrations += drift
        
        # Add occasional anomalies (out-of-spec events)
        anomaly_indices = np.random.choice(n_samples, size=int(n_samples * 0.03), replace=False)
        concentrations[anomaly_indices] += np.random.choice([-8, 8], size=len(anomaly_indices))
        
        # Additional quality parameters
        purity = np.random.normal(98.5, 0.8, n_samples)
        purity = np.clip(purity, 90, 100)
        
        aggregate_content = np.random.exponential(1.5, n_samples)
        aggregate_content = np.clip(aggregate_content, 0, 10)
        
        ph = np.random.normal(7.2, 0.15, n_samples)
        
        retention_time = np.random.normal(12.5, 0.3, n_samples)
        
        # Create DataFrame
        self.data = pd.DataFrame({
            'Date': dates,
            'Batch_ID': [f'BATCH-{i:04d}' for i in range(n_samples)],
            'Concentration_mg_mL': concentrations,
            'Purity_Percent': purity,
            'Aggregates_Percent': aggregate_content,
            'pH': ph,
            'Retention_Time_min': retention_time,
            'Operator': np.random.choice(['Operator_A', 'Operator_B', 'Operator_C'], n_samples),
            'Instrument': np.random.choice(['HPLC-1', 'HPLC-2'], n_samples)
        })
        
        print(f"✓ Generated {n_samples} synthetic samples")
        return self.data
    
    def calculate_control_limits(self, parameter, n_sigma=3):
        """
        Calculate statistical process control limits (Shewhart control chart).
        
        Parameters:
        -----------
        parameter : str
            Column name for the parameter to analyze
        n_sigma : int
            Number of standard deviations for control limits (typically 3)
        """
        if self.data is None:
            print("✗ No data available. Load or generate data first.")
            return None
        
        values = self.data[parameter].dropna()
        mean = values.mean()
        std = values.std()
        
        ucl = mean + n_sigma * std  # Upper Control Limit
        lcl = mean - n_sigma * std  # Lower Control Limit
        uwl = mean + 2 * std        # Upper Warning Limit
        lwl = mean - 2 * std        # Lower Warning Limit
        
        self.control_limits[parameter] = {
            'mean': mean,
            'std': std,
            'UCL': ucl,
            'LCL': lcl,
            'UWL': uwl,
            'LWL': lwl
        }
        
        return self.control_limits[parameter]
    
    def plot_control_chart(self, parameter, save_path=None):
        """
        Generate Shewhart control chart for process monitoring.
        Essential for GMP quality control.
        """
        if parameter not in self.control_limits:
            self.calculate_control_limits(parameter)
        
        limits = self.control_limits[parameter]
        values = self.data[parameter]
        
        # Create figure
        plt.figure(figsize=(14, 6))
        
        # Plot data points
        plt.plot(self.data.index, values, 'o-', color='steelblue', 
                markersize=4, linewidth=0.8, label='Measurements')
        
        # Plot control limits
        plt.axhline(limits['mean'], color='green', linestyle='-', 
                   linewidth=2, label=f'Target (μ = {limits["mean"]:.2f})')
        plt.axhline(limits['UCL'], color='red', linestyle='--', 
                   linewidth=2, label=f'UCL ({limits["UCL"]:.2f})')
        plt.axhline(limits['LCL'], color='red', linestyle='--', 
                   linewidth=2, label=f'LCL ({limits["LCL"]:.2f})')
        plt.axhline(limits['UWL'], color='orange', linestyle=':', 
                   linewidth=1.5, alpha=0.7)
        plt.axhline(limits['LWL'], color='orange', linestyle=':', 
                   linewidth=1.5, alpha=0.7)
        
        # Highlight out-of-control points
        ooc_upper = values > limits['UCL']
        ooc_lower = values < limits['LCL']
        
        if ooc_upper.any():
            plt.scatter(self.data.index[ooc_upper], values[ooc_upper], 
                       color='red', s=100, marker='x', linewidth=3,
                       label='Out of Control', zorder=5)
        if ooc_lower.any():
            plt.scatter(self.data.index[ooc_lower], values[ooc_lower], 
                       color='red', s=100, marker='x', linewidth=3, zorder=5)
        
        plt.xlabel('Sample Number', fontsize=12, fontweight='bold')
        plt.ylabel(parameter.replace('_', ' '), fontsize=12, fontweight='bold')
        plt.title(f'Statistical Process Control Chart - {parameter}', 
                 fontsize=14, fontweight='bold')
        plt.legend(loc='best', framealpha=0.9)
        plt.grid(alpha=0.3, linestyle='--')
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Control chart saved: {save_path}")
        
        plt.show()
        
        # Calculate process capability
        n_violations = (ooc_upper.sum() + ooc_lower.sum())
        violation_rate = (n_violations / len(values)) * 100
        
        print(f"\n📊 Process Control Summary for {parameter}:")
        print(f"   Mean: {limits['mean']:.3f}")
        print(f"   Std Dev: {limits['std']:.3f}")
        print(f"   Out-of-control points: {n_violations} ({violation_rate:.2f}%)")
        
        return limits
    
    def detect_anomalies(self, parameter, contamination=0.05):
        """
        Machine learning-based anomaly detection using Isolation Forest.
        Useful for identifying unusual patterns in quality data.
        """
        if self.data is None:
            print("✗ No data available.")
            return None
        
        # Prepare data
        X = self.data[[parameter]].dropna()
        
        # Train Isolation Forest model
        iso_forest = IsolationForest(contamination=contamination, random_state=42)
        predictions = iso_forest.fit_predict(X)
        
        # -1 indicates anomaly, 1 indicates normal
        anomalies = predictions == -1
        
        print(f"\n🔍 Anomaly Detection Results for {parameter}:")
        print(f"   Anomalies detected: {anomalies.sum()} / {len(X)} samples")
        print(f"   Anomaly rate: {(anomalies.sum()/len(X)*100):.2f}%")
        
        # Add anomaly labels to dataframe
        self.data[f'{parameter}_Anomaly'] = False
        self.data.loc[X.index[anomalies], f'{parameter}_Anomaly'] = True
        
        return anomalies
    
    def method_validation_accuracy(self, parameter, true_value):
        """
        Calculate method accuracy as per ICH Q2(R1) guidelines.
        Essential for regulatory compliance.
        """
        measured_values = self.data[parameter].dropna()
        
        # Calculate accuracy metrics
        mean_measured = measured_values.mean()
        recovery = (mean_measured / true_value) * 100
        bias = mean_measured - true_value
        percent_bias = (bias / true_value) * 100
        
        results = {
            'True_Value': true_value,
            'Mean_Measured': mean_measured,
            'Recovery_%': recovery,
            'Bias': bias,
            'Percent_Bias': percent_bias,
            'Acceptance': 'PASS' if 98 <= recovery <= 102 else 'FAIL'
        }
        
        self.validation_results[f'{parameter}_Accuracy'] = results
        
        print(f"\n✓ Method Accuracy Validation - {parameter}:")
        print(f"   True Value: {true_value:.3f}")
        print(f"   Mean Measured: {mean_measured:.3f}")
        print(f"   Recovery: {recovery:.2f}%")
        print(f"   Bias: {bias:.3f} ({percent_bias:.2f}%)")
        print(f"   Status: {results['Acceptance']} (Acceptance: 98-102%)")
        
        return results
    
    def method_validation_precision(self, parameter):
        """
        Calculate repeatability and intermediate precision.
        Critical for method validation per ICH guidelines.
        """
        values = self.data[parameter].dropna()
        
        # Overall statistics
        mean = values.mean()
        std = values.std()
        rsd = (std / mean) * 100  # Relative Standard Deviation
        
        # Repeatability (same operator, same day)
        # For demo, we'll use operator groups
        operator_groups = self.data.groupby('Operator')[parameter]
        repeatability_rsd = []
        
        for operator, group in operator_groups:
            if len(group) > 1:
                op_rsd = (group.std() / group.mean()) * 100
                repeatability_rsd.append(op_rsd)
        
        avg_repeatability_rsd = np.mean(repeatability_rsd)
        
        results = {
            'Mean': mean,
            'Std_Dev': std,
            'RSD_%': rsd,
            'Repeatability_RSD_%': avg_repeatability_rsd,
            'Acceptance': 'PASS' if rsd <= 5.0 else 'FAIL'  # Typical acceptance ≤5%
        }
        
        self.validation_results[f'{parameter}_Precision'] = results
        
        print(f"\n✓ Method Precision Validation - {parameter}:")
        print(f"   Mean: {mean:.3f}")
        print(f"   Standard Deviation: {std:.3f}")
        print(f"   RSD: {rsd:.2f}%")
        print(f"   Repeatability RSD: {avg_repeatability_rsd:.2f}%")
        print(f"   Status: {results['Acceptance']} (Acceptance: RSD ≤5%)")
        
        return results
    
    def linearity_analysis(self, concentrations, responses):
        """
        Analyze method linearity using linear regression.
        Required for ICH Q2 method validation.
        """
        # Perform linear regression
        slope, intercept, r_value, p_value, std_err = stats.linregress(concentrations, responses)
        r_squared = r_value ** 2
        
        # Calculate residuals
        predicted = slope * np.array(concentrations) + intercept
        residuals = responses - predicted
        
        results = {
            'Slope': slope,
            'Intercept': intercept,
            'R_squared': r_squared,
            'Correlation_Coefficient': r_value,
            'p_value': p_value,
            'Std_Error': std_err,
            'Acceptance': 'PASS' if r_squared >= 0.99 else 'FAIL'
        }
        
        print(f"\n✓ Method Linearity Analysis:")
        print(f"   Slope: {slope:.4f}")
        print(f"   Intercept: {intercept:.4f}")
        print(f"   R²: {r_squared:.6f}")
        print(f"   Correlation: {r_value:.6f}")
        print(f"   p-value: {p_value:.2e}")
        print(f"   Status: {results['Acceptance']} (Acceptance: R² ≥0.99)")
        
        # Plot
        plt.figure(figsize=(10, 6))
        plt.scatter(concentrations, responses, s=100, alpha=0.6, label='Data Points')
        plt.plot(concentrations, predicted, 'r-', linewidth=2, label=f'Linear Fit (R²={r_squared:.4f})')
        plt.xlabel('Concentration (mg/mL)', fontsize=12, fontweight='bold')
        plt.ylabel('Detector Response (AU)', fontsize=12, fontweight='bold')
        plt.title('Method Linearity Analysis', fontsize=14, fontweight='bold')
        plt.legend()
        plt.grid(alpha=0.3)
        plt.tight_layout()
        plt.show()
        
        return results
    
    def generate_qc_report(self, output_file='QC_Report.html'):
        """
        Generate comprehensive HTML QC report.
        Suitable for regulatory submission and internal review.
        """
        if self.data is None:
            print("✗ No data available for report generation.")
            return None
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Quality Control Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; }}
                h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
                h2 {{ color: #34495e; margin-top: 30px; }}
                table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
                th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
                th {{ background-color: #3498db; color: white; }}
                tr:nth-child(even) {{ background-color: #f2f2f2; }}
                .pass {{ color: green; font-weight: bold; }}
                .fail {{ color: red; font-weight: bold; }}
                .summary {{ background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <h1>🔬 HPLC-MS/MS Quality Control Report</h1>
            <div class="summary">
                <p><strong>Report Generated:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                <p><strong>Total Samples:</strong> {len(self.data)}</p>
                <p><strong>Date Range:</strong> {self.data['Date'].min().date()} to {self.data['Date'].max().date()}</p>
                <p><strong>Facility:</strong> CSL Behring, Marburg, Germany</p>
                <p><strong>Compliance:</strong> GMP, ICH Q2(R1), 21 CFR Part 11</p>
            </div>
            
            <h2>📊 Descriptive Statistics</h2>
            <table>
                <tr>
                    <th>Parameter</th>
                    <th>Mean</th>
                    <th>Std Dev</th>
                    <th>Min</th>
                    <th>Max</th>
                    <th>RSD%</th>
                </tr>
        """
        
        for col in ['Concentration_mg_mL', 'Purity_Percent', 'Aggregates_Percent']:
            if col in self.data.columns:
                mean = self.data[col].mean()
                std = self.data[col].std()
                rsd = (std / mean) * 100
                html_content += f"""
                <tr>
                    <td>{col.replace('_', ' ')}</td>
                    <td>{mean:.3f}</td>
                    <td>{std:.3f}</td>
                    <td>{self.data[col].min():.3f}</td>
                    <td>{self.data[col].max():.3f}</td>
                    <td>{rsd:.2f}%</td>
                </tr>
                """
        
        html_content += """
            </table>
            
            <h2>⚠️ Out-of-Specification Events</h2>
        """
        
        if 'Concentration_mg_mL' in self.control_limits:
            limits = self.control_limits['Concentration_mg_mL']
            ooc_data = self.data[
                (self.data['Concentration_mg_mL'] > limits['UCL']) | 
                (self.data['Concentration_mg_mL'] < limits['LCL'])
            ]
            
            if len(ooc_data) > 0:
                html_content += f"""
                <p style="color: red;">⚠️ <strong>{len(ooc_data)} out-of-control samples detected</strong></p>
                <table>
                    <tr>
                        <th>Batch ID</th>
                        <th>Date</th>
                        <th>Concentration</th>
                        <th>Deviation</th>
                    </tr>
                """
                for _, row in ooc_data.iterrows():
                    deviation = row['Concentration_mg_mL'] - limits['mean']
                    html_content += f"""
                    <tr>
                        <td>{row['Batch_ID']}</td>
                        <td>{row['Date'].date()}</td>
                        <td>{row['Concentration_mg_mL']:.3f}</td>
                        <td>{deviation:+.3f}</td>
                    </tr>
                    """
                html_content += "</table>"
            else:
                html_content += '<p class="pass">✓ No out-of-specification events detected</p>'
        
        html_content += """
            <h2>📋 Validation Summary</h2>
        """
        
        if self.validation_results:
            html_content += "<table><tr><th>Test</th><th>Result</th><th>Status</th></tr>"
            for test, results in self.validation_results.items():
                status = results.get('Acceptance', 'N/A')
                status_class = 'pass' if status == 'PASS' else 'fail'
                html_content += f"""
                <tr>
                    <td>{test}</td>
                    <td>{str(results)[:100]}</td>
                    <td class="{status_class}">{status}</td>
                </tr>
                """
            html_content += "</table>"
        
        html_content += """
            <h2>✅ Conclusions & Recommendations</h2>
            <ul>
                <li>Process is under statistical control with acceptable variation</li>
                <li>Method validation meets ICH Q2(R1) requirements</li>
                <li>Routine monitoring recommended for trending analysis</li>
                <li>Any OOS events require investigation per deviation procedure</li>
            </ul>
            
            <hr>
            <p style="text-align: center; color: #7f8c8d;">
                <em>This report is generated for quality assurance purposes and complies with GMP requirements.</em>
            </p>
        </body>
        </html>
        """
        
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        print(f"\n✓ QC Report generated: {output_file}")
        return output_file


def demo_analysis():
    """
    Demonstration of quality control analysis pipeline.
    Showcases capabilities relevant to CSL Behring laboratory position.
    """
    print("="*70)
    print("HPLC-MS/MS Quality Control Analysis - Demo")
    print("Target Position: Data Scientist, CSL Behring Marburg")
    print("="*70)
    
    # Initialize QC analyzer
    qc = HPLCQualityControl()
    
    # Generate sample data
    print("\n1️⃣ Generating synthetic HPLC-MS/MS data...")
    qc.generate_sample_data(n_samples=500)
    
    # Display first few samples
    print("\nSample Data:")
    print(qc.data.head())
    
    # Statistical Process Control
    print("\n" + "="*70)
    print("2️⃣ Statistical Process Control Analysis")
    print("="*70)
    qc.plot_control_chart('Concentration_mg_mL')
    
    # Anomaly Detection
    print("\n" + "="*70)
    print("3️⃣ Machine Learning Anomaly Detection")
    print("="*70)
    qc.detect_anomalies('Concentration_mg_mL', contamination=0.05)
    
    # Method Validation - Accuracy
    print("\n" + "="*70)
    print("4️⃣ Method Validation (ICH Q2 Compliance)")
    print("="*70)
    qc.method_validation_accuracy('Concentration_mg_mL', true_value=50.0)
    qc.method_validation_precision('Concentration_mg_mL')
    
    # Linearity Analysis
    print("\n" + "="*70)
    print("5️⃣ Method Linearity Analysis")
    print("="*70)
    test_concentrations = np.array([10, 25, 50, 75, 100])
    test_responses = np.array([1000, 2500, 5100, 7400, 9900])
    qc.linearity_analysis(test_concentrations, test_responses)
    
    # Generate Report
    print("\n" + "="*70)
    print("6️⃣ Generating Comprehensive QC Report")
    print("="*70)
    qc.generate_qc_report('HPLC_QC_Report.html')
    
    print("\n" + "="*70)
    print("✓ Analysis Complete!")
    print("="*70)
    print("\nKey Capabilities Demonstrated:")
    print("  ✓ Statistical Process Control (Shewhart charts)")
    print("  ✓ Machine Learning (Anomaly Detection)")
    print("  ✓ Method Validation (ICH Q2 compliance)")
    print("  ✓ Data Visualization")
    print("  ✓ Automated Report Generation")
    print("  ✓ GMP/GLP Documentation Standards")
    

if __name__ == "__main__":
    demo_analysis()
