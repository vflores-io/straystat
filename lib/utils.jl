module Utils

using DataFrames
using XLSX, CSV
using StipplePlotly
using PlotlyBase
using Dates


# ===== PRIMARY FUNCTIONS =====

# function to load data from an XLSX file
function load_data(file_path::String)

    workbook = XLSX.readxlsx(file_path)
    sheet = XLSX.sheetnames(workbook)[1]
    data = DataFrame(XLSX.readtable(file_path, sheet));
    
    # convert CollectionDate column to Date
    data.CollectionDate = Date.(data.CollectionDate)

    return data
end

# function to combine the pipeline to calculate summary stats by pathogen
function calculate_summary_stats_by_pathogen_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return calculate_summary_statistics_by_pathogen(comparison_df)
end

function calculate_summary_stats_by_pathogen_and_date_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return calculate_summary_statistics_by_pathogen_and_date(comparison_df)
end

# function to combine the pipeline to calculate summary stats by district (only)
function calculate_summary_stats_by_district_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return calculate_summary_statistics_by_district(comparison_df)
end

# function to combine the pipeline to calculate summary stats by district and collection date
function calculate_summary_stats_by_district_and_date_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return calculate_summary_statistics_by_district_and_date(comparison_df)
end

# function to combine the pipeline to calculate summary stats by district and collection date
function calculate_summary_stats_by_patient_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return calculate_summary_statistics_by_patient_and_date(comparison_df)
end

# function to calculate overall summary stats (for metrics pipeline)
function calculate_overall_test_metrics_pipeline(clean_df::DataFrame)
    # step 1: identify ground truth for qPCR
    ground_truth_qpcr = determine_qPCR_ground_truth(clean_df)
    # step 2: compare qPCR (ground truth) and LAMP test results
    comparison_df = compare_qpcr_lamp(clean_df, ground_truth_qpcr)
    # step 3: calculate and return summary statistics
    return compute_overall_test_metrics(comparison_df)
end

# function to return the summary stats by pathogen
function get_summary_stats_by_pathogen_vars(summary_stats_data::DataFrame)
    pathogens = summary_stats_data.Pathogen
    tp = summary_stats_data.TruePositives
    fp = summary_stats_data.FalsePositives
    tn = summary_stats_data.TrueNegatives
    fn = summary_stats_data.FalseNegatives

    return pathogens, tp, fp, tn, fn

end

# function to return the summary stats by pathogen
function get_summary_stats_by_district_vars(summary_stats_data::DataFrame)
    districts = summary_stats_data.District
    tp = summary_stats_data.TruePositives
    fp = summary_stats_data.FalsePositives
    tn = summary_stats_data.TrueNegatives
    fn = summary_stats_data.FalseNegatives

    return districts, tp, fp, tn, fn

end

# function to get summary grouped by patient
function get_pie_summary_by_patient(data::DataFrame, patient_id::String)
    # convert PatientID col to String type for filtering
    data.PatientID = string.(data.PatientID)

    # filter by PatientID
    patient_data = filter(row -> row.PatientID == patient_id, data)

    # select relevant columns
    selected_columns = [:TestNo, :CollectionDate, :TestType, :Pathogen, :Result]
    
    patient_df = select(patient_data, selected_columns)

    # count the number of results for each pathogen
    pathogen_counts = combine(groupby(patient_df, :Pathogen), nrow => :Count)

    # create a pie trace object for Plotly
    pie_trace = Dict(
        :type => "pie",
        :labels => pathogen_counts.Pathogen,
        :values => pathogen_counts.Count,
        :textinfo => "label+value+percent",
        :hoverinfo => "label+value+percent",
        :marker => Dict(
            # :colors => ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"],  # Custom colors
            :line => Dict(:color => "#FFFFFF", :width => 2)
        )
    )

    # create a layout object for Plotly
    pie_layout = Layout(
        title = "Test Count by Pathogen for Patient $patient_id",
    )

    return patient_df, [pie_trace], pie_layout

end

# function to create an area plot grouped by district
function get_area_plot_by_district(data::DataFrame, district::String)
    # convert PatientID col to String type for filtering
    data.District = string.(data.District)
    
    # filter data by selected district
    district_data = filter(row -> string(row.District) == district, data)

    # use the summary stats from the dataframe
    grouped_by_district_df = combine(groupby(district_data, :CollectionDate), 
        :TruePositives => sum => :TruePositives,
        :FalsePositives => sum => :FalsePositives,
        :TrueNegatives => sum => :TrueNegatives,
        :FalseNegatives => sum => :FalseNegatives
    )

    # create area plot traces for each result type (positive/negative)
    area_traces = [
        scatter(
            x = grouped_by_district_df.CollectionDate,
            y = grouped_by_district_df.TruePositives,
            name = "True Positives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_district_df.CollectionDate,
            y = grouped_by_district_df.FalsePositives,
            name = "False Positives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_district_df.CollectionDate,
            y = grouped_by_district_df.TrueNegatives,
            name = "True Negatives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_district_df.CollectionDate,
            y = grouped_by_district_df.FalseNegatives,
            name = "False Negatives",
            fill = "tonexty",
            stackgroup = "one"
        )
    ]

    # create area plot layout
    area_layout = Layout(
        title = "Test Result Breakdown for District: $district",
        xaxis = attr(title = "Collection Date", showgrid = true, gridcolor = "lightgray"),
        yaxis = attr(title = "Number of Tests", showgrid = true, gridcolor = "lightgray"),
        paper_bgcolor = "white",
        plot_bgcolor = "white",
        showlegend = true
    )

    return area_traces, area_layout

end

# function to create an area plot grouped by patient
function get_area_plot_by_patient(data::DataFrame, patient_id::String)
    # convert PatientID col to String type for filtering
    data.PatientID = string.(data.PatientID)

    # filter data by selected patient
    patient_data = filter(row -> string(row.PatientID) == patient_id, data)

    # use the summary stats from the dataframe
    grouped_by_patient_df = combine(groupby(patient_data, :CollectionDate), 
        :TruePositives => sum => :TruePositives,
        :FalsePositives => sum => :FalsePositives,
        :TrueNegatives => sum => :TrueNegatives,
        :FalseNegatives => sum => :FalseNegatives
    )

    # create area plot traces for each result type (positive/negative)
    area_traces = [
        scatter(
            x = grouped_by_patient_df.CollectionDate,
            y = grouped_by_patient_df.TruePositives,
            name = "True Positives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_patient_df.CollectionDate,
            y = grouped_by_patient_df.FalsePositives,
            name = "False Positives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_patient_df.CollectionDate,
            y = grouped_by_patient_df.TrueNegatives,
            name = "True Negatives",
            fill = "tonexty",
            stackgroup = "one"
        ),
        scatter(
            x = grouped_by_patient_df.CollectionDate,
            y = grouped_by_patient_df.FalseNegatives,
            name = "False Negatives",
            fill = "tonexty",
            stackgroup = "one"
        )
    ]

    # create area plot layout
    area_layout = Layout(
        title = "Test Result Breakdown for PatientID: $patient_id",
        xaxis = attr(title = "Collection Date", showgrid = true, gridcolor = "lightgray"),
        yaxis = attr(title = "Number of Tests", showgrid = true, gridcolor = "lightgray"),
        paper_bgcolor = "white",
        plot_bgcolor = "white",
        showlegend = true
    )

    return area_traces, area_layout

end

# function to create a line plot time history by pathogen
function get_line_plot_by_pathogen(summary_stats::DataFrame)
    # ------ group data by pathogen and collection data already done in the pipeline

    # sort data by CollectionDate, otherwise scatter will show in the order they appear in df
    summary_stats = sort(summary_stats, :CollectionDate)

    # prepare traces using broadcasting for efficiency
    pathogens = unique(summary_stats.Pathogen)

    true_positive_line_traces = [
        scatter(
            x = summary_stats.CollectionDate[summary_stats.Pathogen .== pathogen],
            y = summary_stats.TruePositives[summary_stats.Pathogen .== pathogen],
            mode = "lines+markers",
            name = "$pathogen - True Positives",
            xaxis = "x1",
            yaxis = "y1"
        ) for pathogen in pathogens]

       false_positive_line_traces = [scatter(
            x = summary_stats.CollectionDate[summary_stats.Pathogen .== pathogen],
            y = summary_stats.FalsePositives[summary_stats.Pathogen .== pathogen],
            mode = "lines+markers",
            name = "$pathogen - False Positives",
            xaxis = "x2",
            yaxis = "y2"
        ) for pathogen in pathogens]

        true_negative_line_traces = [
            scatter(
            x = summary_stats.CollectionDate[summary_stats.Pathogen .== pathogen],
            y = summary_stats.TrueNegatives[summary_stats.Pathogen .== pathogen],
            mode = "lines+markers",
            name = "$pathogen - True Negatives",
            xaxis = "x3",
            yaxis = "y3"
        ) for pathogen in pathogens]

        false_negative_line_traces = [scatter(
            x = summary_stats.CollectionDate[summary_stats.Pathogen .== pathogen],
            y = summary_stats.FalseNegatives[summary_stats.Pathogen .== pathogen],
            mode = "lines+markers",
            name = "$pathogen - False Negatives",
            xaxis = "x4",
            yaxis = "y4"
        ) for pathogen in pathogens]

    line_traces = vcat(true_positive_line_traces, false_positive_line_traces, true_negative_line_traces, false_negative_line_traces)

    

    # create line plot layout
    line_layout = Layout(
        xaxis = attr(title = "Collection Date", domain = [0.0, 1.0]),
        yaxis = attr(title = "True Positives", domain = [0.55, 1.0]),
        yaxis2 = attr(title = "False Positives", domain = [0.0, 0.45]),
        yaxis3 = attr(title = "True Negative", domain = [0.0, 0.45]),
        yaxis4 = attr(title = "False Negative", domain = [0.0, 0.45]),
        height = 800,
        paper_bgcolor = "white",
        plot_bgcolor = "white",
        grid = attr(rows = 4, columns = 1, pattern = "independent"),
        showlegend = true
    )

    return line_traces, line_layout

end

# function to create a radar plot with the overall metrics
function plot_overall_metrics_radar_chart(overall_metrics::DataFrame)
    # extract the relevant metrics
    sensitivity = overall_metrics[1, :Value]
    specificity = overall_metrics[2, :Value]
    precision = overall_metrics[3, :Value]
    accuracy = overall_metrics[4, :Value]

    # create the radar plot
    radar_trace = Dict(
        :type => "scatterpolar",
        :r => [sensitivity, specificity, precision, accuracy],
        :theta => ["Sensitivity", "Specificity", "Precision", "Accuracy"],
        :fill => "toself",
        :name => "Overall Test Metrics",
        :marker => Dict(
            :color => "blue"
        )
    )

    # create the layout
    radar_layout = Layout( 
        # title = "Overall Test Metrics Radar Chart",
        polar = attr(
            radialaxis = attr(visible=true, range=[0, 1])  # Adjust the range as needed

        ),
        paper_bgcolor = "white",
        plot_bgcolor = "white",
        showlegend = false
    )

    return [radar_trace], radar_layout

end

# function to create a heatmap by pathogen
function plot_heatmap_by_pathogen(test_metrics_by_pathogen::DataFrame)
    # define x and y axes
    x = names(test_metrics_by_pathogen)[2:end]
    y = test_metrics_by_pathogen.Pathogen

    # define z values - need to make a list of list to pass directly in the HTML tag
    # otherwise it will not work
    z = [ [isnan(v) ? missing : v for v in collect(row)] for row in eachrow(select(test_metrics_by_pathogen, Not(:Pathogen))) ]
    
    return x, y, z
end

function plot_test_results_by_pathogen(df::DataFrame, selected_pathogen::String)

    # filter the data for the selected pathogen
    pathogen_data = filter(row -> row.Pathogen == selected_pathogen, df)

    # filter the data for qPCR and LAMP - drop missing and 0s
    qPCR_data = pathogen_data[pathogen_data.TestType .== "qPCR", :]
    dropmissing!(qPCR_data, :Result)
    filter!(row -> row.Result .!= 0.0, qPCR_data)

    LAMP_data = pathogen_data[pathogen_data.TestType .== "LAMP", :]
    dropmissing!(LAMP_data, :Result)
    filter!(row -> row.Result .!= 0.0, LAMP_data)

    # create the traces
    qPCR_trace = scatter(
        x = 1:length(qPCR_data.Result),
        y = qPCR_data.Result,
        mode = "markers",
        name = "qPCR",
        marker = attr(color = "blue")
    )

    LAMP_trace = scatter(
        x = 1:length(LAMP_data.Result),
        y = LAMP_data.Result,
        mode = "markers",
        name = "LAMP",
        marker = attr(color = "red")
    )

    # create the layout
    layout = Layout(
        title = "Test Results for $selected_pathogen",
        xaxis = attr(title = "Test Number", showgrid = true, gridcolor = "lightgrey"),
        yaxis = attr(title = "Result", showgrid = true, gridcolor = "lightgrey"),
        paper_bgcolor = "white",
        plot_bgcolor = "white",
        showlegend = true
    )

    return [qPCR_trace, LAMP_trace], layout
end

function filter_data_by_date_range(data::DataFrame, start_date, end_date)
    start_date = Date(start_date)
    end_date = Date(end_date)
    
    filtered_data = filter(row -> start_date <= row.CollectionDate <= end_date, data)

    # select only relevant columns
    filtered_data = select(filtered_data, [:PatientID, :CollectionDate, :TestNo, :TestType, :Pathogen, :Result])

    return filtered_data
end

# ===========================================================================



# ===== SECONDARY FUNCTIONS =====

# functions for the summary stats pipeline

# step 1: identify ground truth for qPCR
function determine_qPCR_ground_truth(df::DataFrame)
    grouped_df = groupby(df, [:PatientID, :CollectionDate, :Pathogen])
    
    results = []

    for g in grouped_df
        qPCR_tests = filter(row -> row.TestType == "qPCR", g)
        if nrow(qPCR_tests) > 0
            # if multiple qPCR tests, take the one with the higher TestNo (latest test)
            if nrow(qPCR_tests) > 1
                best_qpcr = qPCR_tests[argmax(qPCR_tests.TestNo), :]
            else
                best_qpcr = qPCR_tests[1, :]
            end
        
            push!(results, best_qpcr)
        end
    end

    # convert the results to a DataFrame
    if length(results) > 0
        ground_truth_qpcr = DataFrame(vcat(results...))
    else
        ground_truth_qpcr = DataFrame()
    end
    
    return ground_truth_qpcr
end

# step 2: compare qPCR (ground truth) and LAMP test results
function compare_qpcr_lamp(df::DataFrame, ground_truth::DataFrame)
    # filter for LAMP Tests only
    lamp_tests = df[df.TestType .== "LAMP", :]
    select!(lamp_tests, [:PatientID, :CollectionDate, :District, :TestNo, :Pathogen, :Result])

    # select the relevant columns from ground_truth dataframe
    select!(ground_truth, [:PatientID, :CollectionDate, :TestNo, :Pathogen, :Result])

    # merge ground truth qPCR data with LAMP results
    merged_df = leftjoin(ground_truth, lamp_tests, on = [:PatientID, :CollectionDate, :Pathogen], makeunique = true)

    # remove rows where Result_1 is missing (i.e. there is nothing to compare to ground truth)
    dropmissing!(merged_df, :Result_1)
    
    # calculate matches and mismatches between qPCR (ground truth) and LAMP
    merged_df[!, :Comparison] = ifelse.((merged_df.Result .!= 0.0 .&& merged_df.Result_1 .!= 0.0) .|| (merged_df.Result .== 0.0 .&& merged_df.Result_1 .== 0.0), true, false)

    rename!(merged_df, "Result_1" => "Result_LAMP")
    rename!(merged_df, "Result" => "Result_qPCR")

    # reorder columns
    col_order = [:PatientID, :CollectionDate, :District, :Pathogen, :Result_qPCR, :Result_LAMP, :Comparison]
    merged_df = select(merged_df, col_order)

    return merged_df
end

# step 3: calculate summary statistics by pathogen
function calculate_summary_statistics_by_pathogen(df::DataFrame)
    # create a dataframe to store summary statistics
    summary_stats = DataFrame(
        Pathogen = String[], 
        TruePositives = Int[], 
        FalsePositives = Int[], 
        TrueNegatives = Int[], 
        FalseNegatives = Int[]
        )

    # group by Pathogen
    grouped_df = groupby(df, :Pathogen)

    # iterate over each group
    for g in grouped_df
        pathogen = unique(g.Pathogen)[1] 

        # true positives(TP) = both qPCR and LAMP tests are non-zero and comparison is true
        tp = sum(g.Result_qPCR .!= 0.0 .&& g.Result_LAMP .!= 0.0 .&& (g.Comparison))
        # false positives(FP) = LAMP test is non-zero but qPCR test is zero and comparison is false
        fp = sum(g.Result_LAMP .!= 0.0 .&& g.Result_qPCR .== 0.0 .&& (.!g.Comparison))
        # true negatives(TN) = both qPCR and LAMP tests are zero and comparison is true
        tn = sum(g.Result_qPCR .== 0.0 .&& g.Result_LAMP .== 0.0 .&& (g.Comparison))
        # false negatives(FN) = LAMP test is zero but qPCR test is non-zero and comparison is false
        fn = sum(g.Result_LAMP .== 0.0 .&& g.Result_qPCR .!= 0.0 .&& (.!g.Comparison))

        # add a new row to the DataFrame with the calculated statistics
        push!(summary_stats, [pathogen, tp, fp, tn, fn])
    end

    return summary_stats
end

function calculate_summary_statistics_by_district(df::DataFrame)
    # create a dataframe to store summary statistics
    summary_stats = DataFrame(
        District = String[], 
        TruePositives = Int[], 
        FalsePositives = Int[], 
        TrueNegatives = Int[], 
        FalseNegatives = Int[]
        )

    # group by district
    grouped_df = groupby(df, :District)

    # iterate over each group
    for g in grouped_df
        district = string.(unique(g.District)[1]) 

        # true positives(TP) = both qPCR and LAMP tests are non-zero and comparison is true
        tp = sum(g.Result_qPCR .!= 0.0 .&& g.Result_LAMP .!= 0.0 .&& (g.Comparison))
        # false positives(FP) = LAMP test is non-zero but qPCR test is zero and comparison is false
        fp = sum(g.Result_LAMP .!= 0.0 .&& g.Result_qPCR .== 0.0 .&& (.!g.Comparison))
        # true negatives(TN) = both qPCR and LAMP tests are zero and comparison is true
        tn = sum(g.Result_qPCR .== 0.0 .&& g.Result_LAMP .== 0.0 .&& (g.Comparison))
        # false negatives(FN) = LAMP test is zero but qPCR test is non-zero and comparison is false
        fn = sum(g.Result_LAMP .== 0.0 .&& g.Result_qPCR .!= 0.0 .&& (.!g.Comparison))

        # add a new row to the DataFrame with the calculated statistics
        push!(summary_stats, [district, tp, fp, tn, fn])
    end
    summary_stats.District = collect(string.(summary_stats.District))
    return summary_stats
end

function calculate_summary_statistics_by_district_and_date(df::DataFrame)
    # create a dataframe to store summary statistics
    summary_stats = DataFrame(
        District = String[], 
        CollectionDate = Date[], 
        TruePositives = Int[], 
        FalsePositives = Int[], 
        TrueNegatives = Int[], 
        FalseNegatives = Int[]
        )

    # group by district and collection date
    grouped_df = groupby(df, [:District, :CollectionDate])

    # iterate over each group
    for g in grouped_df
        district = unique(g.District)[1] 
        collection_date = unique(g.CollectionDate)[1]

        # true positives(TP) = both qPCR and LAMP tests are non-zero and comparison is true
        tp = sum(g.Result_qPCR .!= 0.0 .&& g.Result_LAMP .!= 0.0 .&& (g.Comparison))
        # false positives(FP) = LAMP test is non-zero but qPCR test is zero and comparison is false
        fp = sum(g.Result_LAMP .!= 0.0 .&& g.Result_qPCR .== 0.0 .&& (.!g.Comparison))
        # true negatives(TN) = both qPCR and LAMP tests are zero and comparison is true
        tn = sum(g.Result_qPCR .== 0.0 .&& g.Result_LAMP .== 0.0 .&& (g.Comparison))
        # false negatives(FN) = LAMP test is zero but qPCR test is non-zero and comparison is false
        fn = sum(g.Result_LAMP .== 0.0 .&& g.Result_qPCR .!= 0.0 .&& (.!g.Comparison))

        # add new row to the dataframe with the calculated statistics
        push!(summary_stats, [district, collection_date, tp, fp, tn, fn])

    end

    return summary_stats

end

function calculate_summary_statistics_by_patient_and_date(df::DataFrame)
    # create a dataframe to store summary statistics
    summary_stats = DataFrame(
        PatientID = String[], 
        CollectionDate = Date[], 
        TruePositives = Int[], 
        FalsePositives = Int[], 
        TrueNegatives = Int[], 
        FalseNegatives = Int[]
        )

    # group by patient and collection date
    grouped_df = groupby(df, [:PatientID, :CollectionDate])

    # iterate over each group
    for g in grouped_df
        patient_id = unique(g.PatientID)[1] 
        collection_date = unique(g.CollectionDate)[1]

        # true positives(TP) = both qPCR and LAMP tests are non-zero and comparison is true
        tp = sum(g.Result_qPCR .!= 0.0 .&& g.Result_LAMP .!= 0.0 .&& (g.Comparison))
        # false positives(FP) = LAMP test is non-zero but qPCR test is zero and comparison is false
        fp = sum(g.Result_LAMP .!= 0.0 .&& g.Result_qPCR .== 0.0 .&& (.!g.Comparison))
        # true negatives(TN) = both qPCR and LAMP tests are zero and comparison is true
        tn = sum(g.Result_qPCR .== 0.0 .&& g.Result_LAMP .== 0.0 .&& (g.Comparison))
        # false negatives(FN) = LAMP test is zero but qPCR test is non-zero and comparison is false
        fn = sum(g.Result_LAMP .== 0.0 .&& g.Result_qPCR .!= 0.0 .&& (.!g.Comparison))

        # add new row to the dataframe with the calculated statistics
        push!(summary_stats, [patient_id, collection_date, tp, fp, tn, fn])

    end

    return summary_stats

end

function calculate_summary_statistics_by_pathogen_and_date(df::DataFrame)
    # create a dataframe to store summary statistics
    summary_stats = DataFrame(
        Pathogen = String[], 
        CollectionDate = Date[], 
        TruePositives = Int[], 
        FalsePositives = Int[], 
        TrueNegatives = Int[], 
        FalseNegatives = Int[]
        )

    # group by pathogen and collection date
    grouped_df = groupby(df, [:Pathogen, :CollectionDate])

    # iterate over each group
    for g in grouped_df
        pathogen = unique(g.Pathogen)[1] 
        collection_date = unique(g.CollectionDate)[1]

        # true positives(TP) = both qPCR and LAMP tests are non-zero and comparison is true
        tp = sum(g.Result_qPCR .!= 0.0 .&& g.Result_LAMP .!= 0.0 .&& (g.Comparison))
        # false positives(FP) = LAMP test is non-zero but qPCR test is zero and comparison is false
        fp = sum(g.Result_LAMP .!= 0.0 .&& g.Result_qPCR .== 0.0 .&& (.!g.Comparison))
        # true negatives(TN) = both qPCR and LAMP tests are zero and comparison is true
        tn = sum(g.Result_qPCR .== 0.0 .&& g.Result_LAMP .== 0.0 .&& (g.Comparison))
        # false negatives(FN) = LAMP test is zero but qPCR test is non-zero and comparison is false
        fn = sum(g.Result_LAMP .== 0.0 .&& g.Result_qPCR .!= 0.0 .&& (.!g.Comparison))

        # add new row to the dataframe with the calculated statistics
        push!(summary_stats, [pathogen, collection_date, tp, fp, tn, fn])

    end

    return summary_stats
end

# function to compute the test efficacy metrics
function compute_test_metrics_by_pathogen(summary_stats::DataFrame)
    # create a dataframe to store the computed metrics
    test_metrics = DataFrame(
        Pathogen = [],
        Sensitivity = Float64[],
        Specificity = Float64[],
        Precision = Float64[],
        Accuracy = Float64[]
    )

    # iterate over each row in the summary stats
    for row in eachrow(summary_stats)
        tp = row.TruePositives
        fp = row.FalsePositives
        tn = row.TrueNegatives
        fn = row.FalseNegatives

        # compute the test metrics
        sensitivity = tp / (tp + fn)
        specificity = tn / (tn + fp)
        precision = tp / (tp + fp)
        accuracy = (tp + tn) / (tp + tn + fp + fn)

        # add computed metrics to the dataframe
        push!(test_metrics, [row.Pathogen, sensitivity, specificity, precision, accuracy])
    end

    return test_metrics
end

# function to compute the overall test efficacy metrics
# part of a pipeline function
function compute_overall_test_metrics(df::DataFrame)
    # calculate overall true positives, false positives, true negatives, and false negatives
    tp = sum(df.Result_qPCR .!= 0.0 .&& df.Result_LAMP .!= 0.0 .&& (df.Comparison))
    fp = sum(df.Result_LAMP .!= 0.0 .&& df.Result_qPCR .== 0.0 .&& (.!df.Comparison))
    tn = sum(df.Result_qPCR .== 0.0 .&& df.Result_LAMP .== 0.0 .&& (df.Comparison))
    fn = sum(df.Result_LAMP .== 0.0 .&& df.Result_qPCR .!= 0.0 .&& (.!df.Comparison))

    # compute the test metrics
    sensitivity = tp / (tp + fn)
    specificity = tn / (tn + fp)
    precision = tp / (tp + fp)
    accuracy = (tp + tn) / (tp + tn + fp + fn)

    # store results in a DataFrame
    test_metrics = DataFrame(
        Metric = ["Sensitivity", "Specificity", "Precision", "Accuracy", "True Positives", "False Positives", "True Negatives", "False Negatives"],
        Value = [sensitivity, specificity, precision, accuracy, tp, fp, tn, fn]
    )

    return test_metrics
end



# end of functions for the summary stats pipeline

# function to add dummy data point to df for area plots - by district
function add_dummy_data_point_if_needed_by_district(df::DataFrame)
    # identify districts with only one collection date:

    grouped_df = groupby(df, :District)

    for group in grouped_df
        district = unique(group.District)[1]
        if length(group.CollectionDate) == 1
            # if there is only one unique CollectionDate, add dummy date
            dummy_row = DataFrame(
                District = [district],
                CollectionDate = [minimum(group.CollectionDate) - Day(1)],
                TruePositives = [0],
                FalsePositives = [0],
                TrueNegatives = [0],
                FalseNegatives = [0]
            )

            # append the dummy row to the original data
            df = vcat(df, dummy_row)
        end
    end

    return df

end

# function to add dummy data point to df for area plots - by patient
function add_dummy_data_point_if_needed_by_patient(df::DataFrame)
    # identify patientds with only one collection date:
    grouped_df = groupby(df, :PatientID)

    for group in grouped_df
        patient_id = unique(group.PatientID)[1]
        if length(group.CollectionDate) == 1
            # if there is only one unique CollectionDate, add dummy date
            dummy_row = DataFrame(
                PatientID = [patient_id],
                CollectionDate = [minimum(group.CollectionDate) - Day(1)],
                TruePositives = [0],
                FalsePositives = [0],
                TrueNegatives = [0],
                FalseNegatives = [0]
            )

            # append the dummy row to the original data
            df = vcat(df, dummy_row)
        end
    end

    return df

end

# function to add dummy data point to df for line traces - by pathogen
function add_dummy_data_point_if_needed_by_pathogen(df::DataFrame)
    # identify districts with only one collection date:
    grouped_df = groupby(df, :Pathogen)

    for group in grouped_df
        pathogen = unique(group.Pathogen)[1]
        if length(group.CollectionDate) == 1
            # if there is only one unique CollectionDate, add dummy date
            dummy_row = DataFrame(
                Pathogen = [pathogen],
                CollectionDate = [minimum(group.CollectionDate) - Day(1)],
                TruePositives = [0],
                FalsePositives = [0],
                TrueNegatives = [0],
                FalseNegatives = [0]
            )

            # append the dummy row to the original data
            df = vcat(df, dummy_row)
        end
    end

    return df

end

function delete_uploaded_files(FILE_PATH, FILENAME)

    try
        rm(joinpath(FILE_PATH, FILENAME))
    catch e
        @error "Error deleting uploaded file: $e"    
    end

end

end     # end of module