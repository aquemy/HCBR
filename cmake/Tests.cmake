######################################################################################
### 0) Activate tests
######################################################################################

set(${CMAKE_BINARY_DIR} tests)

if(ZS_GENERATE_TESTS)
enable_testing()
include(CTest REQUIRED)

include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_SOURCE_DIR}/tests)

set(TEST_LIST 
    #ut-combiGenerator
)

foreach(test ${TEST_LIST})
    set("T_${test}_SOURCES" "${CMAKE_SOURCE_DIR}/tests/${test}.cpp")
    add_executable(${test} ${T_${test}_SOURCES} ${FILES})
    add_test(${test} ${test}) 
endforeach()

endif()
