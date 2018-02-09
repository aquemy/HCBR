#include <algorithm>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>

#include <json.hpp>

////////////////////////////////////////////////////////////
/// \brief Parse and validate json parameters
///
/// \param out Stream to output the result
/// \param v Vector to display
///
/// \return std::ostream The stream
////////////////////////////////////////////////////////////
nlohmann::json load_and_validate_parameters(std::string param_file_path) {
	std::ifstream param_file(param_file_path);
    std::stringstream stream;
    stream << param_file.rdbuf();
    auto params = nlohmann::json::parse(stream.str());

    return params;
}

////////////////////////////////////////////////////////////
/// \brief Print a vector
///
/// \param out Stream to output the result
/// \param v Vector to display
///
/// \return std::ostream The stream
////////////////////////////////////////////////////////////
template <typename T>
std::ostream& operator<< (std::ostream& out, const std::vector<T>& v) {
  if ( !v.empty() ) {
    out << '[';
    std::copy(std::begin(v), std::end(v), std::ostream_iterator<T>(out, ", "));
    out << "\b\b]";
  }
  return out;
}
