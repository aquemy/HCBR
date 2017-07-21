######################################################################################
### 0) Documentation
######################################################################################

if(DOXYGEN_FOUND)
    # Directory where the generation will be launched
    set(ZS_DOC_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE INTERNAL "Documentation directory" FORCE)
    # Name of the doxygene configuration file
    set(ZS_DOC_CONFIG_FILE "zenosolver.doxyfile" CACHE INTERNAL "Documentation configuration file")
    if(DOXYGEN_EXECUTABLE)
        # Creating the custom target
        if(UNIX)
            add_custom_target(doc
                COMMAND ${DOXYGEN_EXECUTABLE} ${ZS_DOC_CONFIG_FILE} 
                WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
        endif()
    endif(DOXYGEN_EXECUTABLE)
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/${ZS_DOC_CONFIG_FILE}.cmake"
                   "${ZS_DOC_DIR}/${ZS_DOC_CONFIG_FILE}")
else(DOXYGEN_FOUND)
    message(STATUS "Unable to generate the documentation, Doxygen package not found")
endif(DOXYGEN_FOUND)

