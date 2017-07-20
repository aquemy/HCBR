#include <algorithm>
#include <functional>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <map>
#include <vector>
#include <set>
#include <random>

template <typename T>
std::ostream& operator<< (std::ostream& out, const std::vector<T>& v) {
  if ( !v.empty() ) {
    out << '[';
    std::copy (std::begin(v), std::end(v), std::ostream_iterator<T>(out, ", "));
    out << "\b\b]";
  }
  return out;
}

template <typename T>
std::vector<T> line_to_vect(std::string& line) {
    std::vector<T> v;
    std::istringstream iss(line);
    return std::vector<T>(std::istream_iterator<T>(iss), std::istream_iterator<T>());
}


std::vector<std::vector<int>> read_case_base(std::string path) {
    std::ifstream file(path);
    std::vector<std::vector<int>> cb;
    std::string line;

    if (file) {
        while (std::getline(file, line)) {
            cb.push_back(line_to_vect<int>(line));
        }
    }
    return cb;
}

std::vector<bool> read_mapping(std::string path) {
    std::ifstream file(path);
    std::vector<bool> v;
    std::string line;
    if (file) {
        while (std::getline(file, line)) {
            v.push_back(bool(std::stoi(line)));
        }
    }
    return v;
}

double case_overlap(const std::vector<int>& ref, const std::vector<int>& n) {
    static std::vector<int> i(100); // TODO: Should be the maxium number of feature per case or the feature size space is unknown
    auto it = std::set_intersection(std::begin(ref), std::end(ref), std::begin(n), std::end(n), std::begin(i));
    i.resize(it-std::begin(i));
    return std::size(i) / double(std::size(ref));
}


class CaseBase {
public:
    CaseBase(int m, int max_k = 0)
        : m(m)
        , max_k(max_k) {
        if(max_k > 0) {
            cases.reserve(max_k);
            outcomes.reserve(max_k);
        }

        e_intrinsic_strength[0] = std::map<int,double>{};
        e_intrinsic_strength[1] = std::map<int,double>{};

        c_to_e_overlap[0] = std::map<int, std::map<int, double>>();
        c_to_e_overlap[1] = std::map<int, std::map<int, double>>();
    }


    void add_case(std::vector<int> new_case, int outcome) {
        cases.push_back(new_case);
        outcomes.push_back(outcome);
        auto case_index = std::size(cases) - 1;
        auto intersecting_ei = std::set<int>();
        for(auto f: new_case) {
            if(f_to_e.count(f) == 1) {
                intersecting_ei.insert(f_to_e[f]);
            }
            f_to_c[f].push_back(case_index);
        }

        auto intersection_map = std::map<int, std::vector<int>>{};
        auto intersection = std::vector<int>();
        for(auto ei: intersecting_ei) {
            auto inter = std::vector<int>{};
            for(auto f: intersection_family[ei]) {
                for(auto fc: new_case) {
                    if(f == fc) {
                        inter.push_back(f);
                        intersection.push_back(f);
                    }
                }
            }
            intersection_map[ei] = inter;
        }
        for(auto e: intersection_map) {
            if(std::size(intersection_family[e.first]) == std::size(e.second)) {
                e_to_c[e.first].push_back(case_index);
                e_to_c_by_o[e.first][outcome].push_back(case_index);
                c_to_e[case_index].push_back(e.first);

                e_to_outcome[e.first].push_back(outcome);
                e_to_outcome_count[e.first][outcome]++;
            }
            else if(std::size(e.second) > 0) {
                for(auto f: e.second) {
                    intersection_family[e.first].erase(std::remove(std::begin(intersection_family[e.first]), std::end(intersection_family[e.first]), f), std::end(intersection_family[e.first]));
                }
            
                intersection_family.push_back(e.second);
                auto index_ei = std::size(e_to_c);
                auto index_last_ei = std::size(intersection_family) - 1;
                for(auto f: e.second) {
                    f_to_e[f] = index_last_ei;
                }
                e_to_outcome_count[index_ei] = std::vector<int>{0, 0};
                e_to_outcome[index_last_ei].push_back(outcome);
                e_to_outcome_count[index_last_ei][outcome]++;
                e_to_c[index_last_ei].push_back(case_index);
                e_to_c_by_o[index_last_ei][outcome].push_back(case_index);
                c_to_e[case_index].push_back(index_last_ei);
                for(auto c: e_to_c[e.first]) {
                    e_to_c[index_ei].push_back(c);
                    e_to_c_by_o[index_ei][outcomes[c]].push_back(c);
                    c_to_e[c].push_back(index_ei);
                    e_to_outcome[index_ei].push_back(outcomes[c]);
                    e_to_outcome_count[index_ei][outcomes[c]]++;
                }
            }
        }

        auto discretionary_features = new_case;
        for(auto f: intersection) {
            discretionary_features.erase(std::remove(std::begin(discretionary_features), std::end(discretionary_features), f), std::end(discretionary_features));
        }

        if(std::size(discretionary_features)) {
            intersection_family.push_back(discretionary_features);
            auto index_ei = std::size(intersection_family) - 1;
            e_to_c[index_ei].push_back(case_index);
            e_to_c_by_o[index_ei][outcome].push_back(case_index);
            e_to_outcome[index_ei] = std::vector<int>{outcome};
            e_to_outcome_count[index_ei] = std::vector<int>{0, 0};
            e_to_outcome_count[index_ei][outcome]++;
            c_to_e[case_index].push_back(index_ei);
            auto index_last_ei = std::size(intersection_family) - 1;
            for(auto f: discretionary_features) {
                f_to_e[f] = index_last_ei;
            }
        }

        for (auto e: c_to_e[case_index])
        {
            c_to_e_overlap[0][case_index][e] = mu(0, e, case_index);
            c_to_e_overlap[1][case_index][e] = mu(1, e, case_index);
            calculate_intrinsic_strength(0, e);
            calculate_intrinsic_strength(1, e);
        }
        for (auto e: intersection_map) {
            for(auto c: e_to_c[e.first]) {
                for(auto e2: c_to_e[c]) {
                    c_to_e_overlap[0][c][e2] = mu(0, e2, c);
                    c_to_e_overlap[1][c][e2] = mu(1, e2, c);
                }
            }
        }

    }

    std::pair<std::map<int, std::vector<int>>, std::vector<int>> projection(std::vector<int> new_case) {
        auto intersecting_ei = std::set<int>();
        for(auto f: new_case) {
            if(f_to_e.count(f) == 1) {
                intersecting_ei.insert(f_to_e[f]);
            }
        }

        auto intersection_map = std::map<int, std::vector<int>>{};
        auto intersection = std::vector<int>();
        for(auto ei: intersecting_ei) {
            auto inter = std::vector<int>{};
            for(auto f: intersection_family[ei]) {
                for(auto fc: new_case) {
                    if(f == fc) {
                        inter.push_back(f);
                        intersection.push_back(f);
                    }
                }
            }
            intersection_map[ei] = inter;
        }

        auto discretionary_features = new_case;
        for(auto f: intersection) {
            discretionary_features.erase(std::remove(std::begin(discretionary_features), std::end(discretionary_features), f), std::end(discretionary_features));
        }

        return {intersection_map , discretionary_features};
    }

    double mu(int o, int ei, int c) {
        auto ei_details = intersection_family[ei];
        auto total = double{0};
        double top = e_to_outcome_count[ei][o] * case_overlap(cases[c], ei_details);

        for(auto e: c_to_e[c]) {
            total += e_to_outcome_count[e][o] * case_overlap(cases[c], intersection_family[e]);
        }

        if(total == 0) {
            return 0.;
        } else {
            return top / double(total);
        }
    }

    double _non_normalized_intrinsic_strength(int o, int ei) {
        //auto cases = e_to_c[ei];
        // TODO: Optimized by keeping the index in memory updated during add_case
        //auto ca = std::vector<int>{};
        auto ca = e_to_c_by_o[ei][o];
        //for(int i=0; i < std::size(cases); ++i) {
        //    if(outcomes[cases[i]] == o)
        //        ca.push_back(cases[i]);
        //}
        auto res = double(std::size(intersection_family[ei])) / std::size(f_to_e);
        auto top = double{0.};
        for(auto c: ca) {
            top += c_to_e_overlap[o][c][ei];
        }
        return top * res;
    }

    void calculate_intrinsic_strength(int o, int ei) {
        auto all_strength = double{0.};
        auto ei_strength = _non_normalized_intrinsic_strength(o, ei);
        for(int i=0; i < std::size(intersection_family); ++i) {
            all_strength += _non_normalized_intrinsic_strength(o, i);
        }
        if(all_strength > 0) {
            all_strength = ei_strength / all_strength;
        }
        e_intrinsic_strength[o][ei] = all_strength;
    }

    void display() {
        
        std::cout << "# Case-base with " << m << " features and " << std::size(cases) << " cases" << std::endl;
        /*
        std::cout << "# Case composition" << std::endl;
        auto i = 0;
        for(auto c: cases) {
            std::cout << "C" << i << " -> ";
            for(auto f: c) {
                std::cout << "f" << f << " ";
            }
            std::cout << std::endl;
            i++;
        }

        std::cout << "# Feature to Case mapping" << std::endl;
        for(auto f: f_to_c) {
            std::cout << "f" << f.first << " -> ";
            for(auto c: f.second) {
                std::cout << "C" << c << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Intersection Family" << std::endl;
        i = 0;
        for(auto e: intersection_family) {
            std::cout << "e" << i << " -> ";
            for(auto f: e) {
                std::cout << "f" << f << " ";
            }
            std::cout << std::endl;
            i++;
        }

        std::cout << "# Feature to Ei mapping" << std::endl;
        for(auto i = 0; i < std::size(f_to_e); ++i) {
            std::cout << "f" << i << " -> ";
            std::cout << "e" << f_to_e[i] << " ";
            std::cout << std::endl;
        }

        std::cout << "# Ei to case mapping" << std::endl;
        for(auto e: e_to_c) {
            std::cout << "e" << e.first << " -> ";
            for(auto c: e.second) {
                std::cout << "C" << c << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Case to Ei mapping" << std::endl;
        for(auto c: c_to_e) {
            std::cout << "C" << c.first << " -> ";
            for(auto e: c.second) {
                std::cout << "e" << e << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Ei to Outcome mapping" << std::endl;
        for(auto e: e_to_outcome) {
            std::cout << "e" << e.first << " -> ";
            for(auto o: e.second) {
                std::cout << o << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Ei to Outcome count" << std::endl;
        for(auto e: e_to_outcome_count) {
            std::cout << "e" << e.first << " -> ";
            for(auto o: e.second) {
                std::cout << o << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Overlap Matrix" << std::endl;
        for(int i=0; i < std::size(cases); ++i) {
            std::cout << "# C" << i << " ";
            for(int j=0; j < std::size(cases); ++j) {
                std::cout << std::fixed << std::setprecision(3) << case_overlap(cases[i], cases[j]) << " ";
            }
            std::cout << std::endl;
        }*/

        std::cout << "# Intrinsic Strength" << std::endl;
        for(int i=0; i < std::size(intersection_family); ++i) {
            std::cout << "e" << i << "-> (" << e_intrinsic_strength[0][i] << ", " << e_intrinsic_strength[1][i] <<  ")" << std::endl;
        }
        std::cout << "# Mu(0)" << std::endl;
        for(int i=0; i < std::size(intersection_family); ++i) {
            std::cout << "e" << i << ": ";
            for(int j=0; j < std::size(cases); ++j) {
                std::cout << mu(0, i, j) << " ";
            }
            std::cout << std::endl;
        }

        std::cout << "# Mu(1)" << std::endl;
        for(int i=0; i < std::size(intersection_family); ++i) {
            std::cout << "e" << i << ": ";
            for(int j=0; j < std::size(cases); ++j) {
                std::cout << mu(1, i, j) << " ";
            }
            std::cout << std::endl;
        }


    }

    std::vector<std::vector<int>> intersection_family;
    std::map<int, std::map<int, double>> e_intrinsic_strength;
    std::map<int, std::map<int, std::map<int, double>>> c_to_e_overlap;
private:
    int m;
    int max_k;
    std::vector<std::vector<int>> cases;
    std::vector<int> outcomes;
    std::map<int, std::vector<int>> f_to_c;
    std::map<int, int> f_to_e;

    std::map<int, std::vector<int>> e_to_c;
    std::map<int, std::map<int, std::vector<int>>> e_to_c_by_o;
    std::map<int, std::vector<int>> c_to_e;
    std::map<int, std::vector<int>> e_to_outcome;
    std::map<int, std::vector<int>> e_to_outcome_count;
};


std::random_device rnd_device;
std::mt19937 mersenne_engine(rnd_device());
std::bernoulli_distribution bernouilli(0.5);

std::vector<int> gen_case(int m, int mu) {
    std::uniform_int_distribution<int> mu_dist(1, mu);
    auto c = std::vector<int>(m);
    std::iota(std::begin(c), std::end(c), 0);
    std::shuffle(std::begin(c), std::end(c), rnd_device);
    auto n = mu_dist(mersenne_engine);
    c.resize(n);
    std::sort(std::begin(c), std::end(c));
    return c;
}


int main(int argc, char* argv[]) {

    auto cases = read_case_base("casebase_guess.txt");
    auto outcomes = read_mapping("test_res.txt");

    constexpr auto seed = int{0};
    constexpr auto m = int{4};
    constexpr auto mu = int{10};
    //auto k = int(std::size(cases));
    auto k = int{500};
    constexpr auto eta = double{0.};
    constexpr auto delta = double{1.};


    auto avr_good = double{0.};
    auto avr_good_test = double{0.};

    auto cb = CaseBase(m, k);
    auto nc = std::vector<int>();
    for(auto i = 0; i < k; ++i) {
        //std::cout << "Generating case " << i << std::endl;
        auto o = outcomes[i];
        auto nc = cases[i];//gen_case(m, mu);
        //std::cout << nc << " " << o << std::endl;
        auto proj = cb.projection(nc);

        auto rdf = std::size(proj.second) / double(std::size(nc));
        auto pred_0 = double{0.};
        auto pred_1 = double{0.};

        //std::cout << "# Discretionary features: " << proj.second << std::endl;
        //std::cout << "# Ratio Discretionary features: " << rdf << std::endl;

        std::vector<int> v(std::size(nc)+std::size(proj.second));
        std::vector<int>::iterator it;
        it = std::set_difference (std::begin(nc), std::end(nc), std::begin(proj.second), std::end(proj.second), v.begin());
        v.resize(it-v.begin());

        auto non_disc_features = int(std::size(v));
        for(auto k: proj.first) {
            auto r = std::size(cb.intersection_family[k.first]) / double(non_disc_features);
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
            prediction = bernouilli(mersenne_engine);
        }
        auto pred_test = bernouilli(mersenne_engine);
        avr_good += 1 - abs(outcomes[i] - prediction);
        avr_good_test += 1 - abs(outcomes[i] - pred_test);

        std::cout << i << " " << outcomes[i] << " " << prediction << " " << pred_test << " " << avr_good << " " << avr_good_test << " " << avr_good / (i+1) << " " << avr_good_test / (i+1) << " " << pred_1 << " " << pred_0 << " " << rdf << " " << pred_0 + rdf + eta << std::endl;
        //std::cout << "Case " << i << ": " << nc << std::endl;
        cb.add_case(nc, o);
        //cb.display();
        //std::cout << "#########################################################" << std::endl;
    }
    //cb.display();

    return 0;
}
