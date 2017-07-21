######################################################################################
### 0) Check dependencies according to build and install type
######################################################################################

if(${HCBR_GENERATE_DOC})
    include(FindDoxygen REQUIERED)
endif()

if(${HCBR_PARALLEL})
    find_package(OpenMP)
endif()

if(${HCBR_PLOT})
    include(FindGnuplot REQUIERED)
endif()
