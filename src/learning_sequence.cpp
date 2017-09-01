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
    TCLAP::ValueArg<int> pArg("p","phases","Number of learning phases)", false, -1, "int", cmd);

    cmd.parse(argc, argv);

    // 1. DATA
    // 1.1 CMD verification
    const auto delta = deltaArg.getValue();
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

    auto max_learning_iterations = pArg.getValue();
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
    auto avr_good_0 = 0.;
    auto avr_good_1 = 0.;
    auto avr_bad_0 = 0.;
    auto avr_bad_1 = 0.;
    auto nb_bad_0 = 0;
    auto nb_bad_1 = 0;
    auto nb_good_0 = 0;
    auto nb_good_1 = 0;
    std::tuple<double, double> pred;

    // 3. Initialize the random generator
    std::random_device rnd_device;
    std::mt19937 gen(rnd_device());
    std::srand(std::time(0));

    auto indexes = vector<int>(size(cases));
    std::iota(begin(indexes), end(indexes), 0);

    if(rArg.getValue()) {
        cerr << "Shuffle the casebase..." << endl;
        std::random_shuffle(begin(indexes), end(indexes));
    }

    cerr << "# Add cases..." << endl;
    for(auto i = starting_case; i < limit_examples; ++i) {
        o = outcomes[indexes[i]];
        nc = cases[indexes[i]];
        cb.add_case(nc, o, online);
    }

    cerr << "# Calculate intrinsic strength..." << endl;
    cb.calculate_strength();

    cerr << "# Learning phase..." << endl;
    auto offset_0 = 0.;
    auto offset_1 = 0.;
    auto prev = 0.;
    for(auto i = starting_case; i < limit_examples; ++i)
        if(outcomes[indexes[i]] == 0)
            prev++;

    auto epsilon = 0.;
    for(auto iter = 0; iter < max_learning_iterations; ++iter) 
    {
        cerr << " - Phase " << iter + 1 << endl;
        avr_good = 0.;
        avr_good_1 = 0.;
        avr_good_0 = 0.;
        avr_bad_1 = 0.;
        avr_bad_0 = 0.;
        nb_bad_0 = 0;
        nb_bad_1 = 0;
        nb_good_0 = 0;
        nb_good_1 = 0;
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
            pred = normalize_prediction(pred_0, pred_1, 0, 0, 0, 0);// eta, delta, offset_0, offset_1);// avr_bad_0 / (i+1), avr_bad_1 / (i+1));
            prediction = prediction_rule(pred, rdf, delta, eta, gen);

            avr_good += 1 - abs(o - prediction);
            if(prediction == 1 && o - prediction == 0) {
                avr_good_1 += std::get<1>(pred) - std::get<0>(pred);
                nb_good_1++;
            }
            if(prediction == 0 && o - prediction == 0) {
                avr_good_0 += std::get<1>(pred) - std::get<0>(pred);
                nb_good_0++;
            }

            if(prediction == 1 && o - prediction != 0) {
                avr_bad_1 += std::get<1>(pred) - std::get<0>(pred);
                nb_bad_1++;
            }
            if(prediction == 0 && o - prediction != 0) {
                avr_bad_0 += std::get<1>(pred) - std::get<0>(pred);
                nb_bad_0++;
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
        offset_0 = 0;//-avr_bad_0 / (limit_examples - starting_case + 1) * 1;//prev;
        offset_1 = 0;//avr_bad_1 / (limit_examples - starting_case + 1) * 1;//(1. - prev);
        cerr << "Ratio: " << avr_good << "/" << limit_examples - starting_case << " = " << avr_good / (limit_examples - starting_case) << endl;
        cerr << "Average error toward 0: " << avr_bad_0 / (limit_examples - starting_case + 1) << " (" << nb_bad_0 << ")" << endl;
        cerr << "Average error toward 1: " << avr_bad_1 / (limit_examples - starting_case + 1) << " (" << nb_bad_1 << ")" << endl;
        cerr << "Prev: " << prev / (limit_examples - starting_case) << " (error: " << double(nb_bad_0) / (limit_examples - starting_case) << ") Offset: " <<  offset_0 << " " << offset_1 << endl;
        cerr << "Ratio error 1 : " << double(nb_bad_1) / (nb_bad_0 + nb_bad_1) << endl;

        cerr << "-----------------" << endl;
        cerr << "- " << std::fixed << nb_good_0 << " - " << nb_bad_0 << " - " << endl;
        cerr << "-----------------" << endl;
        cerr << "- " << std::fixed << nb_bad_1 << " - " << nb_good_1 << " - " << endl;
        cerr << "-----------------" << endl;
    }   
    
    auto j = 0;
    // Reset for prediction
    avr_bad_0 = 0.;
    avr_bad_1 = 0.;
    avr_good = 0.;
    auto min_toward_0 = 100000;
    auto min_toward_1 = 100000;
    cerr << "# Predictions" << endl;
    for(auto i = limit_examples+1; i < n_cases; ++i) {
        auto start_iteration = std::chrono::steady_clock::now();
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
        pred = normalize_prediction(pred_0, pred_1, eta, delta, 0, 0); //avr_bad_0 / (i+1), avr_bad_1 / (i+1));

        prediction = prediction_rule(pred, rdf, delta, eta, gen);
        if(std::find(begin(cb.cases), end(cb.cases), nc) != end(cb.cases)) {
            //cerr << "Already in case base" << endl;
            prediction = o;
        }
        avr_good += 1 - abs(o - prediction);
        if(prediction == 1 && o - prediction != 0)
            avr_bad_1 += std::get<1>(pred) - std::get<0>(pred);
        if(prediction == 0 && o - prediction != 0)
            avr_bad_0 += std::get<1>(pred) - std::get<0>(pred);

        ///*
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
        } else {
            if(prediction == 1) {
                if(min_toward_1 > std::get<1>(pred) - std::get<0>(pred)) {
//                    std::cerr << std::get<1>(pred) << " " << std::get<0>(pred) << std::endl;
                    min_toward_1 = std::get<1>(pred) - std::get<0>(pred);
                }
            } else {
                if(min_toward_0 > std::get<0>(pred) - std::get<1>(pred)) {
                    min_toward_0 = (std::get<0>(pred) - std::get<1>(pred));
                }
            }
        }
        //*/
       
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
            cout << std::fixed << c << " " 
                 << o << " " 
                 << prediction << " " 
                 << avr_good << " " 
                 << avr_good / (j+1) << " " 
                 << std::get<1>(pred) << " " 
                 << std::get<0>(pred) << " " 
                 << rdf << " " 
                 << pred_0 + rdf + eta << " " 
                 << iteration_time << " " 
                 << total_time << " " 
                 << std::get<1>(pred) - std::get<0>(pred) << " "
                 << avr_bad_1 / (j+1) << " "
                 << avr_bad_0 / (j+1) << " "
                 << min_toward_1 << " "
                 << min_toward_0 << " "
                 << endl;
            ++j;
        }
    }
    if(verbose) {
        cb.display();
    }
}



