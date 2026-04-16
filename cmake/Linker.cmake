macro(exploration_configure_linker project_name)
  set(exploration_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(exploration_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE exploration_USER_LINKER_OPTION PROPERTY STRINGS ${exploration_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    exploration_USER_LINKER_OPTION_VALUES
    ${exploration_USER_LINKER_OPTION}
    exploration_USER_LINKER_OPTION_INDEX)

  if(${exploration_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${exploration_USER_LINKER_OPTION}', explicitly supported entries are ${exploration_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${exploration_USER_LINKER_OPTION}")
endmacro()
