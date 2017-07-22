#include <algorithm>
#include <iostream>
#include <iterator>
#include <vector>

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
