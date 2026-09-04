:- initialization(testall(asn1_tag)).

%% tag_property_asn(?Int, ?Class, ?PC, ?Numeric, ?NumberOfBytes, ?Bytes).
%
% Properties of an ASN.1 tag. Int is a on-the-wire tag value, Numeric is it's
% ASN.1 value. NumberOfBytes is a length in bytes of Int
%
% FIXME: Has bugs with Numeric value computation, see tests at the bottom.
%
tag_property_asn(Int, Class, PC, Numeric, NumberOfBytes, Bytes) :-
    var(Int) ->
        asn1_tag_property_from_numeric(Int, Class, PC, Numeric, NumberOfBytes, Bytes)
    ;   asn1_tag_property_from_int(Int, Class, PC, Numeric, NumberOfBytes, Bytes).

asn1_tag_property_from_int(Int, Class, PC, Numeric, NumberOfBytes, [A,B,C|Rest]) :-
    pow2_required_digits(8, Int, NumberOfBytes),
    bits(8*NumberOfBytes, [A,B,C|Rest], Int),
    asn1_tag_pc(C, PC),
    phrase(asn1_tag_bits(Bits), Rest),
    bits(_, Bits, Numeric),
    asn1_tag_class(A, B, Class).

asn1_tag_property_from_numeric(Int, Class, PC, Numeric, NumberOfBytes, [A,B,C|Rest]) :-
    asn1_tag_class(A, B, Class),
    asn1_tag_pc(C, PC),
    (
        Class == universal ->
            asn1_tag_universal(Numeric, PC, _)
        ;   true
    ),
    (
        var(NumberOfBytes) ->
            bits(_, Bits, Numeric)
        ;   bits(7*NumberOfBytes, Bits, Numeric)
    ),
    phrase(asn1_tag_bits(Bits), Rest),
    (
        var(NumberOfBytes) ->
            bits(NumberOfBits, [A,B,C|Rest], Int),
            NumberOfBytes is NumberOfBits / 8
        ;   bits(8*NumberOfBytes, [A,B,C|Rest], Int)
    ).

asn1_tag_bits(Bits) --> [1,1,1,1,1], asn1_tag_bits_long(Bits).
asn1_tag_bits(Bits) --> [A,B,C,D,E], { Bits = [A,B,C,D,E], bits(5, Bits, N), N < 0b11111 }.

asn1_tag_bits_long([B2,B3,B4,B5,B6,B7,B8]) --> [0,B2,B3,B4,B5,B6,B7,B8].
asn1_tag_bits_long([B2,B3,B4,B5,B6,B7,B8|R]) --> [1,B2,B3,B4,B5,B6,B7,B8], asn1_tag_bits_long(R).

asn1_tag_class(0, 0, universal).
asn1_tag_class(0, 1, application).
asn1_tag_class(1, 0, context_specific).
asn1_tag_class(1, 1, private).

asn1_tag_pc(0, primitive).
asn1_tag_pc(1, constructed).

asn1_tag_universal(01, primitive, 'BOOLEAN').
asn1_tag_universal(02, primitive, 'INTEGER').
asn1_tag_universal(03, primitive, 'BIT STRING').
asn1_tag_universal(04, primitive, 'OCTET STRING').
asn1_tag_universal(05, primitive, 'NULL').
asn1_tag_universal(06, primitive, 'OBJECT IDENTIFIER').
asn1_tag_universal(09, primitive, 'REAL').
asn1_tag_universal(10, primitive, 'ENUMERATED').
asn1_tag_universal(11, primitive, 'EMBEDDED PDV').
asn1_tag_universal(16, constructed, 'SEQUENCE').
asn1_tag_universal(16, constructed, 'SEQUENCE OF').
asn1_tag_universal(17, constructed, 'SET').
asn1_tag_universal(17, constructed, 'SET OF').
%asn1_tag_universal(_, constructed, 'CHOICE') :- false.
asn1_tag_universal(07, primitive, 'ObjectDescriptor').
asn1_tag_universal(13, primitive, 'RELATIVE-OID').
asn1_tag_universal(08, primitive, 'EXTERNAL').
asn1_tag_universal(12, primitive, 'UTF8String').
asn1_tag_universal(18, primitive, 'NumericString').
asn1_tag_universal(19, primitive, 'PrintableString').
asn1_tag_universal(20, primitive, 'TeletexString').
asn1_tag_universal(20, primitive, 'T61String').
asn1_tag_universal(21, primitive, 'VideotexString').
asn1_tag_universal(22, primitive, 'IA5String').
asn1_tag_universal(25, primitive, 'GraphicString').
asn1_tag_universal(26, primitive, 'VisibleString').
asn1_tag_universal(27, primitive, 'GeneralString').
asn1_tag_universal(28, primitive, 'UniversalString').
asn1_tag_universal(29, primitive, 'CHARACTER STRING').
asn1_tag_universal(30, primitive, 'BMPString').
asn1_tag_universal(14, primitive, 'TIME').
asn1_tag_universal(23, primitive, 'UTCTime').
asn1_tag_universal(24, primitive, 'GeneralizedTime').
asn1_tag_universal(31, primitive, 'DATE').
asn1_tag_universal(32, primitive, 'TIME-OF-DAY').
asn1_tag_universal(33, primitive, 'DATE-TIME').
asn1_tag_universal(34, primitive, 'DURATION').

t(asn1_tag, true, ('The most generic query must succeed at least once' :-
     once(tag_property_asn(_, _, _, _, _, _))
)).

t(asn1_tag, skip, ('There should exist a universal (31...) tag with 2 bytes length (known bug)' :-
    tag_property_asn(_, universal, _, _, 2, _)
)).

t(asn1_tag, skip, ('Tag 31 with 2 bytes serialization must exist (known bug)' :-
    tag_property_asn(_, universal, _, 31, 2, _)
)).

t(asn1_tag, skip, ('Numeric value serialization should find the smallest representation (known bug)' :-
    phrase(asn1_tag_bits([0,0,0,0,0,0,0, 0,0,1,1,1,1,1]), A),
    A == [1,1,1,1,1, 0,0,0,1,1,1,1,1]
)).
