module App

using GenieFramework
using DataFrames
using Dates
using XLSX, CSV
using PlotlyBase, PlotlyJS
include("lib/utils.jl")
using .Utils


@genietools

const FILE_PATH = joinpath("public", "uploads")
mkpath(FILE_PATH)

@app begin
    
    # inputs
    @in selected_file = ""
    @in selected_district = ""
    @in selected_patient_id = ""
    @in selected_patient_id_history = ""
    @in selected_pathogen = ""
    @in raw_data_table_tpagination = DataTablePagination(rows_per_page = 5)
    @in selected_start_date = string(Date(today() - Day(30)))
    @in selected_end_date = string(Date(today()))

    @in DeleteFilesButton = false

    # selections
    @out patient_id_options = [""]
    @out district_options = [""]
    @out pathogen_options = [""]

    # output dataframes and tables
    @out upfiles = readdir(FILE_PATH)
    @out table_files_in_cache = DataTable(DataFrame("Files in Cache" => readdir(FILE_PATH)))
    @out raw_data_df = DataFrame()
    @out raw_data_table = DataTable()
    @out summary_stats_table_by_pathogen = DataTable()
    @out summary_stats_table_by_district = DataTable()
    @out patient_df = DataFrame()
    @out patient_table = DataTable()
    @out table_filtered_by_date = DataTable()
   

    # output plots
    @out pie_trace = []
    @out pie_layout = PlotlyBase.Layout()
    @out area_trace_by_district = []
    @out area_layout_by_district = PlotlyBase.Layout()
    @out area_trace_by_patient = []
    @out area_layout_by_patient = PlotlyBase.Layout()
    @out pathogen_history_line_traces = []
    @out pathogen_history_line_layout = PlotlyBase.Layout()
    @out heatmap_by_pathogen_trace = []
    @out heatmap_by_pathogen_layout = PlotlyBase.Layout()
    @out overall_metrics_radar_trace = []
    @out overall_metrics_radar_layout = PlotlyBase.Layout()
    @out test_results_trace = []
    @out test_results_layout = PlotlyBase.Layout()

    # output variables
    @out pathogens = String[]
    @out tp_pathogen = []
    @out fp_pathogen = []
    @out tn_pathogen = []
    @out fn_pathogen = []
    @out districts = String[]
    @out tp_district = []
    @out fp_district = []
    @out tn_district = []
    @out fn_district = []
    @out heatmap_x = [""]
    @out heatmap_y = [""]
    @out heatmap_z = []

    # private variables
    @private summary_stats_data_by_pathogen = DataFrame()
    @private summary_stats_data_by_district = DataFrame()
    @private summary_stats_data_by_district_and_date = DataFrame()
    @private summary_stats_data_by_patient_and_date = DataFrame()
    @private logreg_input_data_df = DataFrame()
    @private data_filtered_by_date = DataFrame()

    @onchange fileuploads begin
        if !isempty(fileuploads)
            notify(__model__, "File $(fileuploads["name"]) was uploaded successfully")
            filename = fileuploads["name"]
            try
                isdir(FILE_PATH) || mkpath(FILE_PATH)
                mv(fileuploads["path"], joinpath(FILE_PATH, filename), force=true)
            catch e
                @error "Error processing file: $e"
                notify(__model__, "Error processing file: $(fileuploads["name"])")
            end
            fileuploads = Dict{AbstractString,AbstractString}()
        end
        upfiles = readdir(FILE_PATH)
        table_files_in_cache = DataTable(DataFrame("Files in Cache" => readdir(FILE_PATH)))
    end

    @onchange isready, selected_file begin
   
        if !isempty(selected_file)
        raw_data_df = Utils.load_data(joinpath(FILE_PATH, selected_file))
        raw_data_table = DataTable(raw_data_df)

        # calculate summary statistics by pathogen
        summary_stats_data_by_pathogen = Utils.calculate_summary_stats_by_pathogen_pipeline(raw_data_df)
        summary_stats_table_by_pathogen = DataTable(summary_stats_data_by_pathogen)

        # compute efficacy metrics (using the summary statistics from the pipeline above)
        test_metrics_by_pathogen = Utils.compute_test_metrics_by_pathogen(summary_stats_data_by_pathogen)
        # create the heatmap for the test metrics
        heatmap_x, heatmap_y, heatmap_z = Utils.plot_heatmap_by_pathogen(test_metrics_by_pathogen)

        # compute overall efficacy metrics (takes the summary statistics from the pipeline above)
        overall_metrics = Utils.calculate_overall_test_metrics_pipeline(raw_data_df)
        # create the radar plot for the overall metrics
        overall_metrics_radar_trace, overall_metrics_radar_layout = Utils.plot_overall_metrics_radar_chart(overall_metrics)    

        # get summary stats by pathogen for bar plot
        pathogens, tp_pathogen, fp_pathogen, tn_pathogen, fn_pathogen = Utils.get_summary_stats_by_pathogen_vars(summary_stats_data_by_pathogen)

        # calculate summary statistics by district
        summary_stats_data_by_district = Utils.calculate_summary_stats_by_district_pipeline(raw_data_df)
        summary_stats_table_by_district = DataTable(summary_stats_data_by_district)

        # get summary stats by district for bar plot
        districts, tp_district, fp_district, tn_district, fn_district = Utils.get_summary_stats_by_district_vars(summary_stats_data_by_district)

        # get options for selections
        patient_id_options = string.((unique(raw_data_df.PatientID)))
        district_options = string.((unique(raw_data_df.District)))
        pathogen_options = string.((unique(raw_data_df.Pathogen)))

        # generate line plot traces and layout
        summary_stats_data_by_pathogen_and_date = Utils.calculate_summary_stats_by_pathogen_and_date_pipeline(raw_data_df)
        summary_stats_by_pathogen_and_date_with_dummy = Utils.add_dummy_data_point_if_needed_by_pathogen(summary_stats_data_by_pathogen_and_date)
        pathogen_history_line_traces, pathogen_history_line_layout = Utils.get_line_plot_by_pathogen(summary_stats_by_pathogen_and_date_with_dummy)

        end

    end

    @onchange selected_patient_id begin
        # get the summary stats and the pie chart for the selected patient
        patient_df, pie_trace, pie_layout = Utils.get_pie_summary_by_patient(raw_data_df, selected_patient_id)
        patient_table = DataTable(patient_df)
    end

    @onchange selected_district begin

        # generate area plot for the selected district
        summary_stats_data_by_district_and_date = Utils.calculate_summary_stats_by_district_and_date_pipeline(raw_data_df)

        # add dummy data point if needed
        summary_stats_by_district_and_date_with_dummy = Utils.add_dummy_data_point_if_needed_by_district(summary_stats_data_by_district_and_date)
        area_trace_by_district, area_layout_by_district = Utils.get_area_plot_by_district(summary_stats_by_district_and_date_with_dummy, selected_district)
    end

    @onchange selected_patient_id_history begin

        summary_stats_data_by_patient_and_date = Utils.calculate_summary_stats_by_patient_pipeline(raw_data_df)
        # add dummy data point if needed
        summary_stats_by_patient_and_date_with_dummy = Utils.add_dummy_data_point_if_needed_by_patient(summary_stats_data_by_patient_and_date)
        area_trace_by_patient, area_layout_by_patient = Utils.get_area_plot_by_patient(summary_stats_by_patient_and_date_with_dummy, selected_patient_id_history)
    end

    @onchange selected_pathogen begin
        # plot overall test results for the selected pathogen
        test_results_trace, test_results_layout = Utils.plot_test_results_by_pathogen(raw_data_df, selected_pathogen)

    end

    @onchange selected_start_date, selected_end_date begin
        # filter data by date range
        data_filtered_by_date = Utils.filter_data_by_date_range(raw_data_df, selected_start_date, selected_end_date)
        table_filtered_by_date = DataTable(data_filtered_by_date)

    end

    @onbutton DeleteFilesButton begin
        if DeleteFilesButton == true

            for file in readdir(FILE_PATH)

                if file != ""
                    @notify("Deleting File: $file")
                    Utils.delete_uploaded_files(FILE_PATH, file)
                end

            end

            DeleteFilesButton = false
            upfiles = readdir(FILE_PATH)
            table_files_in_cache = DataTable(DataFrame("Files in Cache" => readdir(FILE_PATH)))
            selected_file = ""
            selected_district = ""
            selected_patient_id = ""
            selected_patient_id_history = ""

            @notify("All Files Deleted. Please reload the page or close the browser.")

        end
    end


end

@page("/", "app.jl.html")
end
