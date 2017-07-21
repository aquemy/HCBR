#include <algorithm>
#include <vector>
#include <map>
#include <set>

std::map<int, int> features_count(const std::vector<std::vector<int>>& cases) {
    auto feature_map = std::map<int, int>();
    for(auto c: cases) {
        for(const auto& f: c) {
            if(feature_map.count(f) == 1) {
                feature_map[f]++;
            } else {
                feature_map[f] = 0;
            }
        }
    }
    return feature_map;
}

int total_features_count(const std::map<int, int>& feature_map) {
    auto total = 0;
    for(auto e: feature_map) {
        total += e.second;
    }
    return total;
}

auto random_prediction(auto gen) {
    std::bernoulli_distribution bernouilli(0.5);
    return bernouilli(gen);
}


inline double case_overlap_stl(const std::vector<int>& ref, const std::vector<int>& n) {
    static std::vector<int> i(100); // TODO: Should be the maxium number of feature per case or the feature size space is unknown
    auto it = std::set_intersection(std::begin(ref), std::end(ref), std::begin(n), std::end(n), std::begin(i));
    return double(it-std::begin(i)) / double(std::size(ref));
}

inline double case_overlap(const std::vector<int>& ref, const std::vector<int>& n) {
    auto size_iterate = std::size(ref);
    auto size_compare = std::size(n);
    auto i = int{0};
    auto j = int{0};
    auto count = int{0};
    auto max_val = std::min(ref.back(), n.back()); // Min-max value
    while(i < size_iterate && j < size_compare && ref[i] <= max_val && n[j] <= max_val) {
        if(ref[i] == n[j]) {
            count++;
            j++;
            i++;
        } 
        if (n[j] < ref[i]) {
            while(j < size_compare && n[j] < ref[i]) {
                j++;
            }
        }
        else if (ref[i] < n[j]) {
            while(i < size_iterate && ref[i] < n[j]) {
                i++;
            }
        }
    }
    return count / double(size_iterate);
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
        }

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

    double _non_normalized_intrinsic_strength(int o, int ei) {
        auto ca = e_to_c_by_o[ei][o];
        auto res = double(std::size(intersection_family[ei])) / std::size(f_to_e);
        auto top = double{0.};
        for(auto c: ca) {
            top += c_to_e_overlap[o][c][ei];
        }
        return top * res;
    }

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