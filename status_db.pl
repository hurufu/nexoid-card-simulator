% Status word database.

:- initialization(testall(status_db)).

sw_db_extended(Sw1, Sw2, Status) :- sw_db(Sw1, Sw2, Status).
sw_db_extended(Sw1, Sw2, Status) :- sw_db_rfu(Sw1, Sw2, Status).

sw_db_rfu(0x6A, Sw2, error(wrong_parameters(rfu))) :-
    between(0, 255, Sw2), \+ sw_db(0x6A, Sw2, _).

sw_db(0x62, 0x00, warning(state_of_nvram(unchanged,no_info))).
sw_db(0x63, 0x00, warning(state_of_nvram(changed,no_info))).
sw_db(0x64, 0x00, error(state_of_nvram(unchanged,no_info))).
sw_db(0x64, 0x01, error(state_of_nvram(unchanged,command_timeout))).
sw_db(0x65, 0x00, error(state_of_nvram(changed,no_info))).
sw_db(0x66, 0x00, error(command_not_allowed(no_info))).
sw_db(0x6A, 0x00, error(wrong_parameters(no_info))).
sw_db(0x6A, 0x80, error(wrong_parameters(bad_data))).
sw_db(0x6A, 0x81, error(wrong_parameters(function_not_supported))).
sw_db(0x6A, 0x82, error(wrong_parameters(file_not_found))).
sw_db(0x6A, 0x83, error(wrong_parameters(record_not_found))).
sw_db(0x6A, 0x84, error(wrong_parameters(insufficient_space))).
sw_db(0x6A, 0x85, error(wrong_parameters(lc_inconsistent_with_tlv_structure))).
sw_db(0x6A, 0x86, error(wrong_parameters(incorrect_p1_or_p2))).
sw_db(0x6A, 0x87, error(wrong_parameters(lc_inconsistent_with_p1_or_p2))).
sw_db(0x6A, 0x88, error(wrong_parameters(referenced_data_not_found))).
sw_db(0x6A, 0x89, error(wrong_parameters(file_already_exists))).
sw_db(0x6A, 0x8A, error(wrong_parameters(df_name_already_exists))).
sw_db(0x6A, 0xF0, error(wrong_parameters(wrong_value))).
sw_db(0x6F, 0x00, error(internal(aborted))).
sw_db(0x6F, 0xFF, error(internal(dead))).
sw_db(0x90, 0x00, completed(ok)).
sw_db(0x90, 0x01, warning(pin_not_verified_3_or_more_tries_left)).
sw_db(0x9F, N   , completed(response_size(N))) :- between(0, 255, N).

t(status_db, false, ('sw_db_extended/3 terminates on the most generic query' :-
    sw_db_extended(_,_,_), fail
)).
