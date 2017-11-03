#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <random>

#include <tclap/CmdLine.h>
#include <casebase.cpp>
#include <io.cpp>
#include <utils.cpp>

int main(int argc, char** argv)
{
    using std::cerr;
    using std::cout;
    using std::endl;
    using std::size;
    using std::string;
    using std::vector;

    TCLAP::CmdLine cmd("Hypergraph Case-Base Reasoner", ' ', "0.0.1");

    TCLAP::ValueArg<double> etaArg("e","eta", "Hyperparameter to add an offset to the default class for prediction", false, 0.,"double", cmd);
    TCLAP::ValueArg<double> deltaArg("d","delta", "Hyperparameter to control the information treshold. Must be in [0,1].", false, 0.,"double", cmd);
    TCLAP::ValueArg<double> gammaArg("g","gamma", "Hyperparameter to control the information treshold. Must be in [0,1].", false, 0.,"double", cmd);

    TCLAP::ValueArg<string> cbFileArg("c", "casebase","File with the casebase description", true, "", "string", cmd);
    TCLAP::ValueArg<string> oFileArg("o", "outcomes","File with the outomes corresponding to the casebase", true, "", "string", cmd);
    TCLAP::ValueArg<string> fFileArg("f", "features","File with the feature mapping", false, "", "string", cmd);
    TCLAP::ValueArg<int> lArg("l","limit", "Limit on the number of cases to add into the casebase", false, -1, "int", cmd);
    TCLAP::SwitchArg sArg("s","sample-out","Start to calculate the prediction ratio after the training set", cmd, false);
    TCLAP::SwitchArg kArg("k","keep-offset","Keep the offset in the case number even with the sample-out option", cmd, false);
    TCLAP::ValueArg<int> nArg("n","starting-number", "Starting case number", false, 0, "int", cmd);
    TCLAP::SwitchArg rArg("r","shuffle","Shuffle the casebase (testing purposes)", cmd, false);
    TCLAP::SwitchArg vArg("v","log","Log the final casebase", cmd, false);
    TCLAP::SwitchArg iArg("i","online","Online algorithm (strength calculated incrementally or at once after insertion)", cmd, false);
    TCLAP::ValueArg<int> pArg("p","phases","Number of learning phases", false, -1, "int", cmd);
    TCLAP::ValueArg<int> runArg("b","run-number","ID to identify a run (used for log files name)", false, 0, "int", cmd);
    TCLAP::SwitchArg hArg("z","heuristic","Check if a case is already in a case-bas to reuse its results", cmd, false);
    TCLAP::ValueArg<int> seedArg("x","seed","Seed for the pseudo-random generator", false, 0, "int", cmd);

    cmd.parse(argc, argv);
    std::fstream log;

    // 1. DATA
    // 1.1 CMD verification
    const auto delta = deltaArg.getValue();
    const auto gamma = gammaArg.getValue();
    //if(delta < -1 || delta > 1)
    //    throw std::domain_error("Delta must belong to [-1,1]");

    const auto eta = etaArg.getValue();

    const auto casebase_file = cbFileArg.getValue();
    const auto outcomes_file = oFileArg.getValue();
    const auto features_file = fFileArg.getValue();

    auto cases = vector<vector<int>>();
    auto outcomes = vector<bool>();
    auto features = std::map<int, string>();
    try {
        cases = read_case_base(casebase_file);
        outcomes = read_mapping(outcomes_file);
        features = read_features(features_file);
        if(size(cases) == 0)
            throw std::domain_error("# The casebase file could not be found or is empty.");
        if(size(outcomes) == 0)
            throw std::domain_error("# The outcomes file could not be found or is empty.");
        if(size(cases) != size(outcomes))
            throw std::domain_error("# The outcomes and casebase sizes are different.");
    } catch (std::exception &e)  // catch any exceptions
    {
        cerr << "Error: " << e.what() << endl;
        return 3;
    }

    auto max_learning_iterations = pArg.getValue();
    auto online = iArg.getValue();
    auto verbose = vArg.getValue();
    auto starting_case = nArg.getValue(); // TODO: Test validity
    auto sample_out = sArg.getValue();
    auto keep_offset = kArg.getValue();
    auto limit_examples = lArg.getValue() + starting_case;
    auto run_id = runArg.getValue();
    auto check_if_in_cb = hArg.getValue();
    if(limit_examples > size(cases)) {
        cout << "# The limit is larger than the cases in the casebase. It will be set to the casebase size." << endl;
        limit_examples = size(cases);
    }
    else if(limit_examples == -1) {
        limit_examples = size(cases);
    }
    if(sample_out && limit_examples == size(cases)) {
        cout << "# Disable the Sample Out feature due to the limit parameter being as large as the casebase." << endl;
    }

    // 1.2 Number of features detection
    auto n_cases = size(cases);
    auto feature_map = features_count(cases);
    auto total_features = total_features_count(feature_map);
    decltype(cases)::iterator min_e, max_e;
    std::tie(min_e, max_e) = std::minmax_element(begin(cases), end(cases),
                            [](const vector<int>& v1, const vector<int>& v2) {
                                 return size(v1) < size(v2);
                             });
    auto avg_features = std::accumulate(begin(cases), end(cases), 0,
                            [](int& r, const vector<int>& v) {
                                 return r + size(v);
                             }) / double(n_cases);
    cerr << "# Online: " << online << endl;
    cerr << "# Verbose level: " << verbose << endl;
    cerr << "# Cases: " << n_cases << endl;
    cerr << "# Total features: " << total_features << endl;
    cerr << "# Unique features: " << size(feature_map) << " (ratio: " << size(feature_map) / double(total_features) << ")" << endl;
    cerr << "# Minimum case size: " << size(*min_e) << endl;
    cerr << "# Maximum case size: " << size(*max_e) << endl;
    cerr << "# Average case size: " << avg_features << endl;


    // 2. Create the necessary variables
    auto cb = CaseBase(size(feature_map), n_cases);

    auto avr_good = 0.;
    auto total_time = 0.;
    auto nc = cases[0];
    auto o = outcomes[0];
    decltype(cb.projection(cases[0])) proj;
    auto prediction = 0;
    auto pred_0 = 0.;
    auto pred_1 = 0.;
    auto r = 0.;
    auto rdf = 0.;
    auto avr_good_0 = 0.;
    auto avr_good_1 = 0.;
    auto avg_diff_bad_0 = 0.;
    auto avg_diff_bad_1 = 0.;
    auto nb_bad_0 = 0;
    auto nb_bad_1 = 0;
    auto nb_good_0 = 0;
    auto nb_good_1 = 0;
    std::tuple<double, double> pred;

    auto log_run = std::string{};
    if (!std::ifstream(log_file_name("hcbr", -1))) {
        log_run += "Total Cases, \
                 Total Features, \
                 Unique Features, \
                 Min. Case Size, \
                 Max. Case Size, \
                 Avg. Case Size, \
                 Building Time, \
                 Examples, \
                 Unique Features in Examples, \
                 Unique Feature Ratio in Examples, \
                 Cardinal Partition, \
                 Min. Card. Part. Element, \
                 Max. Card. Part. Element, \
                 Avg. Card. Part. Element, \
                 Min. |v|, \
                 Max. |v|, \
                 Avg. |v|, \
                 Min. |e| per case, \
                 Max. |e| per case, \
                 Avg. |e| per case, \
                 Min. |e| per case (%), \
                 Max. |e| per case (%), \
                 Avg. |e| per case (%), \
                 Min. DFR in Examples, \
                 Max. DFR in Examples, \
                 Avg. DFR in Examples, \
                 Min. DFR in Examples (%), \
                 Max. DFR in Examples (%), \
                 Avg. DFR in Examples (%), \
                 Strength Time, \
                 Learning Time, \
                 Learning Phases, \
                 Learning Accuracy, \
                 Learning True Positive, \
                 Learning False Positive, \
                 Learning False Negative, \
                 Learning True Negative, \
                 Prediction Time, \
                 Cardinal Prediction, \
                 Total Time, \
                 Min. DFR in Prediction, \
                 Max. DFR in Prediction, \
                 Avg. DFR in Prediction, \
                 Min. DFR in Prediction (%), \
                 Max. DFR in Prediction (%), \
                 Avg. DFR in Prediction (%), \
                 Prediction Accuracy, \
                 True Positive, \
                 False Positive, \
                 False Negative, \
                 True Negative, \
                 True Positive Rate (sensitivity), \
                 True Negative Rate (specificity), \
                 Positive Prediction Value (precision), \
                 Negative Prediction Value, \
                 False Negative Rate (miss rate), \
                 False Positive Rate (fall-out), \
                 False Discovery Rate, \
                 False Omission Rate, \
                 F1 Score, \
                 Matthews Correlation Coefficient, \
                 Avg. Diff. True Pos., \
                 Avg. Diff. True Neg., \
                 Avg. Diff. False Pos., \
                 Avg. Diff. False Neg., \
                 Avg. Diff. True Pos. (%), \
                 Avg. Diff. True Neg. (%), \
                 Avg. Diff. False Pos. (%), \
                 Avg. Diff. False Neg. (%), \
                 Ratio Cases already in CB , \
                 \n";
    }
    log_run += std::to_string(n_cases) + " , " 
             + std::to_string(total_features) + " , " 
             + std::to_string(size(feature_map)) + " , "
             + std::to_string(size(*min_e)) + " , "
             + std::to_string(size(*max_e)) + " , "
             + std::to_string(avg_features) + " , ";

    auto log_training = std::string{};
    if (!std::ifstream(log_file_name("training", run_id))) {
        log_training += "Time, \
                 Accuracy, \
                 True Positive, \
                 False Positive, \
                 False Negative, \
                 True Negative, \
                 Avg. Diff. True Pos., \
                 Avg. Diff. True Neg., \
                 Avg. Diff. False Pos., \
                 Avg. Diff. False Neg., \
                 Avg. Diff. True Pos. (%), \
                 Avg. Diff. True Neg. (%), \
                 Avg. Diff. False Pos. (%), \
                 Avg. Diff. False Neg. (%)";
        log.open(log_file_name("training", run_id), std::fstream::in | std::fstream::out | std::fstream::app);
        log << log_training << endl;
        log.close();
    }
    auto log_prediction = std::string{};
    if (!std::ifstream(log_file_name("prediction", run_id))) {
        log_prediction += "Time, \
                 Total Time, \
                 Case Size, \
                 Outcome, \
                 Prediction, \
                 Cumulated Good Predictions, \
                 Accuracy, \
                 Score 1, \
                 Score 0, \
                 Cardinal Partition, \
                 RDF, \
                 RDF (%), \
                 True Positive, \
                 False Positive, \
                 False Negative, \
                 True Negative, \
                 Avg. Diff. True Pos., \
                 Avg. Diff. True Neg., \
                 Avg. Diff. False Pos., \
                 Avg. Diff. False Neg., \
                 Avg. Diff. True Pos. (%), \
                 Avg. Diff. True Neg. (%), \
                 Avg. Diff. False Pos. (%), \
                 Avg. Diff. False Neg. (%)";
        log.open(log_file_name("prediction", run_id), std::fstream::in | std::fstream::out | std::fstream::app);
        log << log_prediction << endl;
        log.close();
    }

    // 3. Initialize the random generator
    std::random_device rnd_device;
    std::mt19937 gen(rnd_device());
    auto seed = seedArg.getValue();
    if(seed == 0)
        seed = std::time(0);
    std::srand(seed);

    auto indexes = vector<int>(size(cases));
    std::iota(begin(indexes), end(indexes), 0);

    if(rArg.getValue()) {
        cerr << "# Shuffle the casebase..." << endl;
        std::random_shuffle(begin(indexes), end(indexes));
    }

    auto start_global_time = std::chrono::steady_clock::now();
    cerr << "# Add cases..." << endl;
    auto start_time = std::chrono::steady_clock::now();
    for(auto i = starting_case; i < limit_examples; ++i) {
        o = outcomes[indexes[i]];
        nc = cases[indexes[i]];
        cb.add_case(nc, o, false);//online);
    }
    auto end_time = std::chrono::steady_clock::now();
    auto diff = end_time - start_time;
    auto time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();

    auto min_size_e = size(cb.intersection_family[0]);
    auto max_size_e = min_size_e;
    auto average_size_e = 0.;
    auto cardinal_part = size(cb.intersection_family);
    for(const auto& e: cb.intersection_family) {
        auto n = size(e);
        average_size_e += n;
        if(min_size_e > n)
            min_size_e = n;
        if(max_size_e < n)
            max_size_e = n ;
    }

    auto min_size_v = total_features;
    auto max_size_v = 0;
    auto average_size_v = 0.;
    auto dfr_exists = false;
    auto min_dfr = total_features;
    auto max_dfr = 0;
    auto avg_dfr = 0.;
    auto min_dfr_pct = 1.;
    auto max_dfr_pct = 0.;
    auto avg_dfr_pct = 0.;
    for(const auto& e: cb.e_to_c) {
        auto n = size(e.second);
        average_size_v += n;
        if(min_size_v > n)
            min_size_v = n;
        if(max_size_v < n)
            max_size_v = n ;

        auto m = size(cb.intersection_family[e.first]);
        if(n == 1) {
            dfr_exists = true;
            auto dfr = double(m);
            auto dfr_pct = double(m) / size(cb.cases[e.second[0]]);
            if(min_dfr_pct > dfr_pct)
                min_dfr_pct = dfr_pct;
            if(max_dfr_pct < dfr_pct)
                max_dfr_pct = dfr_pct;
            avg_dfr_pct += dfr_pct;
            if(min_dfr > dfr)
                min_dfr = dfr;
            if(max_dfr < dfr)
                max_dfr = dfr;
            avg_dfr += dfr;
        }
    }
    if(!dfr_exists) {
        min_dfr = 0.;
        max_dfr = 0.;
        avg_dfr = 0.;
        min_dfr_pct = 0.;
        max_dfr_pct = 0.;
        avg_dfr_pct = 0.;
    }

    auto min_size_ec = total_features;
    auto max_size_ec = 0;
    auto average_size_ec = 0.;

    auto min_size_ec_pct = float(total_features);
    auto max_size_ec_pct = 0.;
    auto average_size_ec_pct = 0.;

    auto cardinal_ec = size(cb.c_to_e);
    for(const auto& e: cb.c_to_e) {
        auto local_min_size_ec_pct = float(total_features);
        auto local_max_size_ec_pct = 0.;
        auto local_average_size_ec_pct = 0.;
        auto m = size(cb.cases[e.first]);
        auto is_drf = false;
        for(const auto& i: e.second) {
            auto n = size(cb.intersection_family[i]);
            local_average_size_ec_pct += double(n) / m;
            if(local_min_size_ec_pct > n)
                local_min_size_ec_pct = n;
            if(local_max_size_ec_pct < n)
                local_max_size_ec_pct = n;
        }
        auto n = size(e.second);
        local_max_size_ec_pct /= m;
        local_min_size_ec_pct /= m;
        local_average_size_ec_pct /= n;

        if(min_size_ec_pct > local_min_size_ec_pct)
            min_size_ec_pct = local_min_size_ec_pct;
        if(max_size_ec_pct < local_max_size_ec_pct)
            max_size_ec_pct = local_max_size_ec_pct;

        average_size_ec_pct += local_average_size_ec_pct;

        average_size_ec += n;
        if(min_size_ec > n)
            min_size_ec = n;
        if(max_size_ec < n)
            max_size_ec = n;
    }
    log_run += std::to_string(time) + " , " 
              + std::to_string(limit_examples - starting_case) + " , "
              + std::to_string(size(cb.f_to_e)) + " , "
              + std::to_string(double(size(cb.f_to_e)) / size(feature_map)) + " , "
              + std::to_string(cardinal_part) + " , "
              + std::to_string(min_size_e) + " , "
              + std::to_string(max_size_e) + " , "
              + std::to_string(average_size_e / cardinal_part) + " , "
              + std::to_string(min_size_v) + " , "
              + std::to_string(max_size_v) + " , "
              + std::to_string(average_size_v / cardinal_part) + " , "
              + std::to_string(min_size_ec) + " , "
              + std::to_string(max_size_ec) + " , "
              + std::to_string(average_size_v / cardinal_ec) + " , "
              + std::to_string(100 * min_size_ec_pct) + " , "
              + std::to_string(100 * max_size_ec_pct) + " , "
              + std::to_string(100 * average_size_ec_pct / (limit_examples - starting_case)) + " , "
              + std::to_string(min_dfr) + " , "
              + std::to_string(max_dfr) + " , "
              + std::to_string(avg_dfr / (limit_examples - starting_case)) + " , "
              + std::to_string(100 * min_dfr_pct) + " , "
              + std::to_string(100 * max_dfr_pct) + " , "
              + std::to_string(100 * avg_dfr_pct / (limit_examples - starting_case)) + " , ";


    cerr << "# Calculate intrinsic strength..." << endl;
    start_time = std::chrono::steady_clock::now();
    cb.calculate_strength(log, run_id);
    end_time = std::chrono::steady_clock::now();
    diff = end_time - start_time;
    time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
    log_run += std::to_string(time) + " , ";

    cerr << "# Learning phase..." << endl;
    auto offset_0 = 0.;
    auto offset_1 = 0.;
    auto prev = 0.;
    start_time = std::chrono::steady_clock::now();
    for(auto i = starting_case; i < limit_examples; ++i)
        if(outcomes[indexes[i]] == 0)
            prev++;

    auto epsilon = 0.;
    auto accuracy = 0.;
    auto avg_diff_bad_0_pct = 0.;
    auto avg_diff_bad_1_pct = 0.;
    avr_good = 0.;
    auto avg_diff_good_0 = 0.;
    auto avg_diff_good_1 = 0.;
    auto avg_diff_good_0_pct = 0.;
    auto avg_diff_good_1_pct = 0.;
    auto tp = 0;
    auto tn = 0;
    auto fp = 0;
    auto fn = 0;
    log.open(log_file_name("training", run_id), std::fstream::in | std::fstream::out | std::fstream::app);
    for(auto iter = 0; iter < max_learning_iterations; ++iter) 
    {
        auto start_time = std::chrono::steady_clock::now();
        cerr << " - Phase " << iter + 1 << endl;
        avg_diff_good_0 = 0.;
        avg_diff_good_1 = 0.;
        avg_diff_good_0_pct = 0.;
        avg_diff_good_1_pct = 0.;
        tp = 0;
        tn = 0;
        fp = 0;
        fn = 0;
        log_training = "";
        for(auto i = starting_case; i < limit_examples; ++i) 
        {
            o = outcomes[indexes[i]];
            nc = cases[indexes[i]];
            proj = cb.projection(nc);
            rdf = std::size(proj.second) / double(std::size(nc));
           
            decltype(nc) v(size(nc)+size(proj.second));
            decltype(v)::iterator it;
            it = std::set_difference(begin(nc), end(nc), begin(proj.second), end(proj.second), begin(v));
            v.resize(it-begin(v));

            auto non_disc_features = int(size(v));
            pred_0 = 0.;
            pred_1 = 0.;
            for(const auto& k: proj.first) {
                r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                pred_0 += r * cb.e_intrinsic_strength[0][k.first];
                pred_1 += r * cb.e_intrinsic_strength[1][k.first];
            }
            pred = normalize_prediction(pred_0, pred_1, eta, delta, 0, 0);// eta, delta, offset_0, offset_1);// avg_diff_bad_0 / (i+1), avg_diff_bad_1 / (i+1));
            prediction = prediction_rule(pred, rdf, gamma, eta, gen);

            avr_good += 1 - abs(o - prediction);
            if(prediction == 1)
                if(o - prediction != 0) {
                    fp += 1;
                    avg_diff_bad_1 += std::get<1>(pred) - std::get<0>(pred);
                    avg_diff_bad_1_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
                }
                else {
                    tp += 1;
                    avg_diff_good_1 += std::get<1>(pred) - std::get<0>(pred);
                    avg_diff_good_1_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
                }
            if(prediction == 0)
                if (o - prediction != 0) {
                    fn += 1;
                    avg_diff_bad_0 += std::get<1>(pred) - std::get<0>(pred);
                    avg_diff_bad_0_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
                }
                else {
                    tn += 1;
                    avg_diff_good_0 += std::get<1>(pred) - std::get<0>(pred);
                    avg_diff_good_0_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
                }

            if(abs(o - prediction) != 0) {
                for(const auto& k: proj.first) {
                    if(prediction == 1) {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        //cb.e_intrinsic_strength[0][k.first] += double(nb_bad_0) / (nb_bad_0 + nb_bad_1) * r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        //cb.e_intrinsic_strength[1][k.first] -= double(nb_bad_1) / (nb_bad_0 + nb_bad_1) * r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[0][k.first] += r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[1][k.first] -= r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    } else {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        //cb.e_intrinsic_strength[0][k.first] -= double(nb_bad_0) / (nb_bad_0 + nb_bad_1) * r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        //cb.e_intrinsic_strength[1][k.first] += double(nb_bad_1) / (nb_bad_0 + nb_bad_1) * r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[0][k.first] -= r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[1][k.first] += r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    }
                }
            }
            /*
            if(abs(o - prediction) != 0) {
                for(const auto& k: proj.first) {
                    if(prediction == 1) {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        cb.e_intrinsic_strength[0][k.first] += double(nb_bad_0) / (nb_bad_0 + nb_bad_1) * r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[1][k.first] -= double(nb_bad_1) / (nb_bad_0 + nb_bad_1) * r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    } else {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        cb.e_intrinsic_strength[0][k.first] -= double(nb_bad_0) / (nb_bad_0 + nb_bad_1) * r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[1][k.first] += double(nb_bad_1) / (nb_bad_0 + nb_bad_1) * r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    }
                }
            }
            */

             /*
            if(abs(o - prediction) == 0) {
                for(const auto& k: proj.first) {
                    if(prediction == 1) {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        //cb.e_intrinsic_strength[0][k.first] -= r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        cb.e_intrinsic_strength[1][k.first] += r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    } else {
                        r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                        cb.e_intrinsic_strength[0][k.first] += r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                        //cb.e_intrinsic_strength[1][k.first] -= r * abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                    }
                }
            }
            //*/
        }
        auto end_time = std::chrono::steady_clock::now();
        auto diff = end_time - start_time;
        auto time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
        offset_0 = 0;//-avg_diff_bad_0 / (limit_examples - starting_case + 1) * 1;//prev;
        offset_1 = 0;//avg_diff_bad_1 / (limit_examples - starting_case + 1) * 1;//(1. - prev);
        cerr << "Ratio: " << (tp + tn) << "/" << (tp + tn + fn + fp) << " = " << (tp + tn) / double(tp + tn + fn + fp) << endl;
        cerr << "Average error toward 0: " << avg_diff_bad_0 / (limit_examples - starting_case + 1) << " (" << fn << ")" << endl;
        cerr << "Average error toward 1: " << avg_diff_bad_1 / (limit_examples - starting_case + 1) << " (" << fp << ")" << endl;
        cerr << "Prev: " << prev / (limit_examples - starting_case) << " (error: " << double(fn) / (limit_examples - starting_case) << ") Offset: " <<  offset_0 << " " << offset_1 << endl;
        cerr << "Ratio error 1 : " << double(fp) / (fn + fp) << endl;

        cerr << "-----------------" << endl;
        cerr << "- " << std::fixed << tp << " - " << fp << " - " << endl;
        cerr << "-----------------" << endl;
        cerr << "- " << std::fixed << fn << " - " << tn << " - " << endl;
        cerr << "-----------------" << endl;

        log << std::to_string(time) << " , "
            << (tp + tn) / double(tp + tn + fn + fp) << " , "
            << std::to_string(tp) << " , "
            << std::to_string(tn) << " , "
            << std::to_string(fp) << " , "
            << std::to_string(fn) << " , "
            << std::to_string(avg_diff_good_1 / tp) << " , "
            << std::to_string(avg_diff_good_0 / tn) << " , "
            << std::to_string(avg_diff_bad_1 / fp) << " , "
            << std::to_string(avg_diff_bad_0 / fn) << " , "
            << std::to_string(100 * avg_diff_good_1_pct / tp) << " , "
            << std::to_string(100 * avg_diff_good_0_pct / tn) << " , "
            << std::to_string(100 * avg_diff_bad_1_pct / fp) << " , "
            << std::to_string(100 * avg_diff_bad_0_pct / fn) << " , "
            << std::endl;
    }
    log.close();
    end_time = std::chrono::steady_clock::now();
    diff = end_time - start_time;
    time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
    log_run += std::to_string(time) + " , " 
            + std::to_string(max_learning_iterations) + " , "
            + std::to_string((tp + tn) / double(tp + tn + fn + fp)) + " , "
              + std::to_string(tp) + " , "
              + std::to_string(fp) + " , "
              + std::to_string(fn) + " , "
              + std::to_string(tn) + " , ";
    
    auto j = 0;
    // Reset for prediction
    avg_diff_bad_0 = 0.;
    avg_diff_bad_1 = 0.;
    avg_diff_bad_0_pct = 0.;
    avg_diff_bad_1_pct = 0.;
    avr_good = 0.;
    avg_diff_good_0 = 0.;
    avg_diff_good_1 = 0.;
    avg_diff_good_0_pct = 0.;
    avg_diff_good_1_pct = 0.;
    tp = 0;
    tn = 0;
    fp = 0;
    fn = 0;
    auto min_toward_0 = 100000;
    auto min_toward_1 = 100000;
    auto already_in_cb = 0;
    auto already_in_cb_good = 0;

    dfr_exists = false;
    min_dfr = total_features;
    max_dfr = 0;
    avg_dfr = 0;
    min_dfr_pct = 1.;
    max_dfr_pct = 0.;
    avg_dfr_pct = 0.;
    cerr << "# Predictions" << endl;
    log.open(log_file_name("prediction", run_id), std::fstream::in | std::fstream::out | std::fstream::app);
    start_time = std::chrono::steady_clock::now();
    for(auto i = limit_examples+1; i < n_cases; ++i) {
        log_prediction = "";
        auto start_iteration = std::chrono::steady_clock::now();
        o = outcomes[indexes[i]];
        nc = cases[indexes[i]];

        proj = cb.projection(nc);
        auto m = std::size(proj.second);
        rdf =  m / double(std::size(nc));
        if(min_dfr_pct > rdf)
            min_dfr_pct = rdf;
        if(max_dfr_pct < rdf)
            max_dfr_pct = rdf;
        avg_dfr_pct += rdf;

        if(min_dfr > m)
            min_dfr = m;
        if(max_dfr < m)
            max_dfr = m;
        avg_dfr += m;
        
        decltype(nc) v(size(nc)+size(proj.second));
        decltype(v)::iterator it;
        it = std::set_difference(begin(nc), end(nc), begin(proj.second), end(proj.second), begin(v));
        v.resize(it-begin(v));

        auto non_disc_features = int(size(v));
        pred_0 = 0.;
        pred_1 = 0.;
        for(const auto& k: proj.first) {
            r = size(cb.intersection_family[k.first]) / double(non_disc_features);
            pred_0 += r * cb.e_intrinsic_strength[0][k.first];
            pred_1 += r * cb.e_intrinsic_strength[1][k.first];
           
        }
        pred = normalize_prediction(pred_0, pred_1, eta, delta, 0, 0); //avg_diff_bad_0 / (i+1), avg_diff_bad_1 / (i+1));

        prediction = prediction_rule(pred, rdf, gamma, eta, gen);

        if (check_if_in_cb) {
            auto index_case = std::find(begin(cb.cases), end(cb.cases), nc);
            
            if(index_case != end(cb.cases)) {
                already_in_cb++;
                auto index = std::distance(begin(cb.cases), index_case);
                if(cb.outcomes[index] == o){
                    already_in_cb_good++;
                }
                //cerr << "Already in case base " << cb.outcomes[index] << " " << o << endl;
                prediction = cb.outcomes[index];
            }
        }
        avr_good += 1 - abs(o - prediction);
        if(prediction == 1)
            if(o - prediction != 0) {
                fp += 1;
                avg_diff_bad_1 += std::get<1>(pred) - std::get<0>(pred);
                avg_diff_bad_1_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
            }
            else {
                tp += 1;
                avg_diff_good_1 += std::get<1>(pred) - std::get<0>(pred);
                avg_diff_good_1_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
            }
        if(prediction == 0)
            if (o - prediction != 0) {
                fn += 1;
                avg_diff_bad_0 += std::get<1>(pred) - std::get<0>(pred);
                avg_diff_bad_0_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
            }
            else {
                tn += 1;
                avg_diff_good_0 += std::get<1>(pred) - std::get<0>(pred);
                avg_diff_good_0_pct += (std::get<1>(pred) - std::get<0>(pred)) / (std::get<1>(pred) + std::get<0>(pred));
            }

        ///*
        if (online) {
          if(abs(o - prediction) != 0) {
              for(const auto& k: proj.first) {
                  if(prediction == 1) {
                      r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                      cb.e_intrinsic_strength[0][k.first] += r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]) / size(proj.first); //abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                      cb.e_intrinsic_strength[1][k.first] -= r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]) / size(proj.first);//abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                  } else {
                      r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                      cb.e_intrinsic_strength[0][k.first] -= r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]) / size(proj.first);//abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                      cb.e_intrinsic_strength[1][k.first] += r * abs(cb.e_intrinsic_strength[0][k.first] - cb.e_intrinsic_strength[1][k.first]) / size(proj.first);//abs(std::get<1>(pred) - std::get<0>(pred)) / size(proj.first);
                  }
              }
          }
        }
        //*/
       
        //cb.display();
        auto end_iteration = std::chrono::steady_clock::now();
        auto diff = end_iteration - start_iteration;
        auto iteration_time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
        total_time += iteration_time;
        accuracy = avr_good / (j+1);
        if(!sample_out || i > limit_examples) {
            auto c = j;
            if(keep_offset) {
                c = i;
            }
            cout << std::fixed << c << " " 
                 << o << " " 
                 << prediction << " " 
                 << avr_good << " " 
                 << accuracy << " " 
                 << std::get<1>(pred) << " " 
                 << std::get<0>(pred) << " "
                 << rdf << " " 
                 << pred_0 + rdf + eta << " " 
                 << iteration_time << " " 
                 << total_time << " " 
                 << std::get<1>(pred) - std::get<0>(pred) << " "
                 << avg_diff_bad_1 / (j+1) << " "
                 << avg_diff_bad_0 / (j+1) << " "
                 << min_toward_1 << " "
                 << min_toward_0 << " "
                 << endl;
            ++j;
            log << iteration_time << " , " 
                << total_time << " , " 
                << std::size(nc) << " , " 
                << o << " , " 
                << prediction << " , " 
                << avr_good << " , " 
                << accuracy << " , " 
                << std::get<1>(pred) << " , " 
                << std::get<0>(pred) << " , "
                << std::size(proj.first) << " , "
                << std::size(proj.second) << " , "
                << rdf << " , " 
                << std::to_string(tp) << " , "
                << std::to_string(fp) << " , "
                << std::to_string(fn) << " , "
                << std::to_string(tn) << " , "
                << std::to_string(avg_diff_good_1 / tp) << " , "
                << std::to_string(avg_diff_good_0 / tn) << " , "
                << std::to_string(avg_diff_bad_1 / fp) << " , "
                << std::to_string(avg_diff_bad_0 / fn) << " , "
                << std::to_string(100 * avg_diff_good_1_pct / tp) << " , "
                << std::to_string(100 * avg_diff_good_0_pct / tn) << " , "
                << std::to_string(100 * avg_diff_bad_1_pct / fp) << " , "
                << std::to_string(100 * avg_diff_bad_0_pct / fn) << " , "
                << endl;
        }
    }
    log.close();
    std::cerr << "# Already in case-base: " << already_in_cb << " " << already_in_cb_good / double(already_in_cb) << std::endl;
    end_time = std::chrono::steady_clock::now();
    diff = end_time - start_time;
    time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
    log_run += std::to_string(time) + " , " + std::to_string(n_cases - limit_examples + 1) + " , ";

    diff = end_time - start_global_time;
    time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
    log_run += std::to_string(time) + " , "
              + std::to_string(min_dfr) + " , "
              + std::to_string(max_dfr) + " , "
              + std::to_string(avg_dfr / (limit_examples - starting_case)) + " , "
              + std::to_string(100 * min_dfr_pct) + " , "
              + std::to_string(100 * max_dfr_pct) + " , "
              + std::to_string(100 * avg_dfr_pct / (limit_examples - starting_case)) + " , " 
              + std::to_string(accuracy) + " , "
              + std::to_string(tp) + " , "
              + std::to_string(fp) + " , "
              + std::to_string(fn) + " , "
              + std::to_string(tn) + " , "
              + std::to_string(tp / double(tp + fn))  + " , "
              + std::to_string(tn / double(tn + fp))  + " , "
              + std::to_string(tp / double(tp + fp))  + " , "
              + std::to_string(tn / double(tn + fn))  + " , "
              + std::to_string(fn / double(fn + tp))  + " , "
              + std::to_string(fp / double(fp + tn))  + " , "
              + std::to_string(fp / double(fp + tp))  + " , "
              + std::to_string(fn / double(fn + tn))  + " , "
              + std::to_string(2*tp / double(2*tp + fp + fn))  + " , "
              + std::to_string(((long long int)(tp * tn) - (fp * fn)) / sqrt((long long int)(tp + fp)*(tp + fn)*(tn + fp)*(tn + fn)))  + " , "
              + std::to_string(avg_diff_good_1 / tp) + " , "
              + std::to_string(avg_diff_good_0 / tn) + " , "
              + std::to_string(avg_diff_bad_1 / fp) + " , "
              + std::to_string(avg_diff_bad_0 / fn) + " , "
              + std::to_string(100 * avg_diff_good_1_pct / tp) + " , "
              + std::to_string(100 * avg_diff_good_0_pct / tn) + " , "
              + std::to_string(100 * avg_diff_bad_1_pct / fp) + " , "
              + std::to_string(100 * avg_diff_bad_0_pct / fn) + " , "
              + std::to_string(already_in_cb_good / double(already_in_cb)) + " , ";
    cerr << ((long long int)(tp * tn) - (fp * fn)) / sqrt((long long int)(tp + fp)*(tp + fn)*(tn + fp)*(tn + fn)) << endl;
    log.open(log_file_name("hcbr", -1), std::fstream::in | std::fstream::out | std::fstream::app);
    log << log_run << std::endl;
    log.close();

    if(verbose) {
        cb.display();
    }
}
 