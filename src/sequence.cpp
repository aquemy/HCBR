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

    TCLAP::ValueArg<string> cbFileArg("c", "casebase","File with the casebase description", true, "", "string", cmd);
    TCLAP::ValueArg<string> oFileArg("o", "outcomes","File with the outomes corresponding to the casebase", true, "", "string", cmd);

    cmd.parse(argc, argv);

    // 1. DATA
    // 1.1 CMD verification
    const auto delta = deltaArg.getValue();
    if(delta < 0 || delta > 1)
        throw std::domain_error("Delta must belong to [0,1]");

    const auto eta = etaArg.getValue();

    const auto casebase_file = cbFileArg.getValue();
    const auto outcomes_file = oFileArg.getValue();

    auto cases = vector<vector<int>>();
    auto outcomes = vector<bool>();
    try {
        cases = read_case_base(casebase_file);
        outcomes = read_mapping(outcomes_file);
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

    cout << "Cases: " << n_cases << endl;
    cout << "Total features: " << total_features << endl;
    cout << "Unique features: " << size(feature_map) << " (ratio: " << size(feature_map) / double(total_features) << ")" << endl;
    cout << "Minimum case size: " << size(*min_e) << endl;
    cout << "Maximum case size: " << size(*max_e) << endl;
    cout << "Average case size: " << avg_features << endl;


    // 2. Create the necessary variables
    auto cb = CaseBase(size(feature_map), n_cases);

    auto avr_good = 0.;
    auto total_time = 0.;
    auto nc = cases[0];
    auto o = outcomes[0];
    decltype(cb.projection(cases[0])) proj;

    // 3. Initialize the random generator
    std::random_device rnd_device;
    std::mt19937 gen(rnd_device());

    for(auto i = 0; i < n_cases; ++i) {
        auto start_iteration = std::chrono::steady_clock::now();
        //std::cout << "Generating case " << i << std::endl;
        o = outcomes[i];
        nc = cases[i];//gen_case(m, mu);
        //std::cout << nc << " " << o << std::endl;
        proj = cb.projection(nc);

        auto rdf = std::size(proj.second) / double(std::size(nc));
        auto pred_0 = double{0.};
        auto pred_1 = double{0.};

        //std::cout << "# Discretionary features: " << proj.second << std::endl;
        //std::cout << "# Ratio Discretionary features: " << rdf << std::endl;

        decltype(nc) v(size(nc)+size(proj.second));
        decltype(v)::iterator it;
        it = std::set_difference(begin(nc), end(nc), begin(proj.second), end(proj.second), begin(v));
        v.resize(it-begin(v));

        auto non_disc_features = int(size(v));
        for(const auto& k: proj.first) {
            auto r = size(cb.intersection_family[k.first]) / double(non_disc_features);
            pred_0 += cb.e_intrinsic_strength[0][k.first] * r;
            pred_1 += cb.e_intrinsic_strength[1][k.first] * r;
        }
        //std::cout << "# Raw Pred(1,0)=(" << pred_0 << ", " << pred_1 << ")" << std::endl;
        auto a = pred_0;
        auto b = pred_1;

        if (a + b  + eta > 0) {
            pred_0 = (a + eta) / (a + b  + eta);
            pred_1 = b / (a + b + eta);
        }
        else {
            pred_0 = 0;
            pred_1 = 0;
        }
        //std::cout << "# Final Pred(1,0)=(" << pred_0 << ", " << pred_1 << ")" << std::endl;
        auto prediction = int{0};
        if(pred_1 > pred_0) {
            prediction = 1;
        }
        //std::cout <<  "Prediction: " << prediction << " - Real value: " << outcomes[i] << std::endl;
        if(rdf > delta) {
            prediction = random_prediction(gen);
        }
        avr_good += 1 - abs(outcomes[i] - prediction);
        
        cb.add_case(nc, o);
        //cb.display();
        auto end_iteration = std::chrono::steady_clock::now();
        auto diff = end_iteration - start_iteration;
        auto iteration_time = std::chrono::duration<double, std::ratio<1, 1>>(diff).count();
        //iteration_time /= 1000000.0;
        total_time += iteration_time;

        cout << std::fixed << i << " " << outcomes[i] << " " << prediction << " " << avr_good << " " << avr_good / (i+1) << " " << pred_1 << " " << pred_0 << " " << rdf << " " << pred_0 + rdf + eta << " " << iteration_time << " " << total_time << endl;
    }
    //cb.display();
}