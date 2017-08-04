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
    TCLAP::ValueArg<double> deltaArg("d","delta", "Hyperparameter to control the information treshold. Must be in [0,1].", false, 1.,"double", cmd);

    TCLAP::ValueArg<string> cbFileArg("c", "casebase","File with the casebase description", true, "", "string", cmd);
    TCLAP::ValueArg<string> oFileArg("o", "outcomes","File with the outomes corresponding to the casebase", true, "", "string", cmd);
    TCLAP::ValueArg<string> fFileArg("f", "features","File with the feature mapping", false, "", "string", cmd);
    TCLAP::ValueArg<int> lArg("l","limit", "Limit on the number of cases to add into the casebase", false, -1, "int", cmd);
    TCLAP::SwitchArg sArg("s","sample-out","Start to calculate the prediction ratio after the training set", cmd, false);
    TCLAP::SwitchArg kArg("k","keep-offset","Keep the offset in the case number even with the sample-out option", cmd, false);
    TCLAP::ValueArg<int> nArg("n","starting-number", "Starting case number", false, 0, "int", cmd);
    TCLAP::SwitchArg rArg("r","shuffle","Shuffle the casebase (testing purposes)", cmd, false);
    TCLAP::SwitchArg vArg("v","log","Log the final casebase", cmd, true);
    TCLAP::SwitchArg iArg("i","online","Online algorithm (strength calculated incrementally or at once after insertion)", cmd, false);

    cmd.parse(argc, argv);

    // 1. DATA
    // 1.1 CMD verification
    const auto delta = deltaArg.getValue();
    if(delta < 0 || delta > 1)
        throw std::domain_error("Delta must belong to [0,1]");

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
            throw std::domain_error("The casebase file could not be found or is empty.");
        if(size(outcomes) == 0)
            throw std::domain_error("The outcomes file could not be found or is empty.");
        if(size(cases) != size(outcomes))
            throw std::domain_error("Delta must belong to [0,1]");
    } catch (std::exception &e)  // catch any exceptions
    {
        cerr << "Error: " << e.what() << endl;
        return 3;
    }

    auto online = iArg.getValue();
    auto verbose = vArg.getValue();
    auto starting_case = nArg.getValue(); // TODO: Test validity
    auto sample_out = sArg.getValue();
    auto keep_offset = kArg.getValue();
    auto limit_examples = lArg.getValue() + starting_case;
    if(limit_examples > size(cases)) {
        cout << "The limit is larger than the cases in the casebase. It will be set to the casebase size." << endl;
        limit_examples = size(cases);
    }
    else if(limit_examples == -1) {
        limit_examples = size(cases);
    }
    if(sample_out && limit_examples == size(cases)) {
        cout << "Disable the Sample Out feature due to the limit parameter being as large as the casebase." << endl;
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
                             }) / n_cases;
    cerr << "Online: " << online << endl;
    cerr << "Verbose level: " << verbose << endl;
    cerr << "Cases: " << n_cases << endl;
    cerr << "Total features: " << total_features << endl;
    cerr << "Unique features: " << size(feature_map) << " (ratio: " << size(feature_map) / double(total_features) << ")" << endl;
    cerr << "Minimum case size: " << size(*min_e) << endl;
    cerr << "Maximum case size: " << size(*max_e) << endl;
    cerr << "Average case size: " << avg_features << endl;


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

    // 3. Initialize the random generator
    std::random_device rnd_device;
    std::mt19937 gen(rnd_device());

    auto indexes = vector<int>(size(cases));
    std::iota(begin(indexes), end(indexes), 0);

    if(rArg.getValue()) {
        cerr << "Shuffle the casebase..." << endl;
        std::random_shuffle(begin(indexes), end(indexes));
    }

    auto j = 0;
    for(auto i = starting_case; i < n_cases; ++i) {
        auto start_iteration = std::chrono::steady_clock::now();
        //std::cerr << "Generating case " << i  << " | Index: " << indexes[i] << std::endl;
        o = outcomes[indexes[i]];
        nc = cases[indexes[i]];
        //std::cout << nc << " " << o << std::endl;
        if(!sample_out || i > limit_examples)
        {
            if(!online)
                cb.calculate_strength();
            proj = cb.projection(nc);
            rdf = std::size(proj.second) / double(std::size(nc));
            //std::cout << "# Discretionary features: " << proj.second << std::endl;
            //std::cout << "# Ratio Discretionary features: " << rdf << std::endl;

            decltype(nc) v(size(nc)+size(proj.second));
            decltype(v)::iterator it;
            it = std::set_difference(begin(nc), end(nc), begin(proj.second), end(proj.second), begin(v));
            v.resize(it-begin(v));

            auto non_disc_features = int(size(v));
            pred_0 = 0.;
            pred_1 = 0.;
            auto res_0 = vector<std::tuple<int, double, double>>();
            auto res_1 = vector<std::tuple<int, double, double>>();
            for(const auto& k: proj.first) {
                r = size(cb.intersection_family[k.first]) / double(non_disc_features);
                pred_0 += r * cb.e_intrinsic_strength[0][k.first];
                pred_1 += r * cb.e_intrinsic_strength[1][k.first];
                res_0.push_back(std::tuple<int, double, double>(k.first, pred_0, r));
                res_1.push_back(std::tuple<int, double, double>(k.first, pred_1, r));
            }
            std::sort(std::begin(res_0), std::end(res_0), [&](std::tuple<int, double, double>& i, std::tuple<int, double, double>& j) {
                return std::get<1>(i) * std::get<2>(i) > std::get<1>(j) * std::get<2>(j); });

            std::sort(std::begin(res_1), std::end(res_1), [&](std::tuple<int, double, double>& i, std::tuple<int, double, double>& j) {
                return std::get<1>(i) * std::get<2>(i) > std::get<1>(j) * std::get<2>(j) ; });


            /*
            std::cout << "Case: " << nc << std::endl;
            for(auto f: nc) {
                cout << features[f] << " ";
            }
            cout << endl;
            std::cout << "For class 0: " << std::endl;
            auto max = size(res_0);
            if(size(res_0) < max)
                max = size(res_0);
            for(auto i = 0; i < max; ++i) {
                auto fs = cb.intersection_family[std::get<0>(res_0[i])];
                std::cout << "e" << std::get<0>(res_0[i]) << " s0=" << std::get<1>(res_0[i])  <<" s1=" << std::get<1>(res_1[i]) << " r=" << std::get<2>(res_0[i]) << " ";
                //pred_0 += std::get<1>(res_0[i]) * std::get<2>(res_0[i]);
                for(auto f: fs) {
                    cout << features[f] << " ";
                }
                cout << endl;
            }
            //*/

            //std::cout << "# Raw Pred(1,0)=(" << pred_0 << ", " << pred_1 << ")" << std::endl;
            auto pred = normalize_prediction(pred_0, pred_1, eta);

            //std::cout << "# Final Pred(1,0)=(" << pred_0 << ", " << pred_1 << ")" << std::endl;
            prediction = prediction_rule(pred, rdf, delta, gen);
            avr_good += 1 - abs(outcomes[i] - prediction);
        }

        if(i < limit_examples) {
            //cerr << "Add " << i << " / " << limit_examples << endl;
            cb.add_case(nc, o, online);
        }
        //cb.display();
        auto end_iteration = std::chrono::steady_clock::now();
        auto diff = end_iteration - start_iteration;
        auto iteration_time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
        total_time += iteration_time;

        if(!sample_out || i > limit_examples) {
            auto c = j;
            if(keep_offset) {
                c = i;
            }
            cout << std::fixed << c << " " << outcomes[i] << " " << prediction << " " << avr_good << " " << avr_good / (j+1) << " " << pred_1 << " " << pred_0 << " " << rdf << " " << pred_0 + rdf + eta << " " << iteration_time << " " << total_time << endl;
            ++j;
        }
    }
    if(verbose) {
        cb.display();
    }
    /*
    auto best_0 = cb.best_features(0, 10);
    std::cerr << "BEST E" << std::endl;
    for(auto i = 0; i < size(cb.intersection_family); ++i) {
        cout << abs(cb.e_intrinsic_strength[0][i] - cb.e_intrinsic_strength[1][i]) / (cb.e_intrinsic_strength[0][i] + cb.e_intrinsic_strength[1][i]) << " " << cb.e_intrinsic_strength[0][i] << " " << cb.e_intrinsic_strength[1][i] << " ";
        auto fs = cb.intersection_family[i];
        for(auto f: fs) {
            cout << features[f] << " ";
        }
        cout << endl;
    }
    //*/
}



