import "findjmap.m" : FindJMap;
import "OpenImage/main/ModularCurves.m" : CreateModularCurveRec;
import "Code to compute models for genus 0 groups.m" : ComputeModel;

intrinsic GetLevelAndGensFromLabel(label::MonStgElt) ->
	  RngIntElt, SeqEnum[SeqEnum[RngIntElt]]
{.}
    level := StringToInteger(Split(label, ".")[1]);
    input := Read("input_data/" * label);
    input_lines := Split(input, "\n");
    if IsEmpty(input_lines) then
	gens := [];
    else
	gens := [StringToInteger(x) : x in Split(input_lines[1], ",")];
    end if;
    // Should be a list of 2x2 matrices, so number of elements divisible by 4.
    assert #gens mod 4 eq 0;
    // Here we transpose the matrices, because Zywina's code uses the 
    // transposed convention of Galois action
    gens := [[gens[4*i-3],gens[4*i-1],gens[4*i-2],gens[4*i]] 
	     : i in [1..#gens div 4]];
    return level, gens;
end intrinsic;			    

intrinsic ProcessModel(label::MonStgElt) -> Crv, FldFunRatMElt[FldRat],
                                            RngIntElt, SeqEnum[CspDat]
{.}
    level, gens := GetLevelAndGensFromLabel(label);
    genus := StringToInteger(Split(label, ".")[3]);
    // Apparently, Rakvi's code does not handle X(1)
    if (genus eq 0) and (not IsEmpty(gens)) then
	// !! TODO - is this precision always enough?
	Ggens := {GL(2,Integers(level))!g : g in gens};
	X<x,y,z>, j, has_rational_pt := ComputeModel(level,Ggens,10);
	num := Evaluate(ChangeRing(Numerator(j), Rationals()), x);
	denom := Evaluate(ChangeRing(Denominator(j), Rationals()), x);
	num := Evaluate(num, [x/z,y/z,1]);
	denom := Evaluate(denom, [x/z,y/z,1]);
	j := num / denom;
	model_type := (has_rational_pt) select 1 else 2;
	cusps := CuspOrbits(level, gens);
	// !! TODO - fix this so that the cusps on H will match the cusps on
	// the model
	// We only need one representative of each orbit
	cusps := [orb[1] : orb in cusps];
	P1 := ProjectiveSpace(Rationals(),1);
	jmap := map<X->P1 | [Numerator(j), Denominator(j)]>;
	cusp_scheme := (P1![1,0]) @@ jmap;
	cusp_coords := AssociativeArray();
	field_idx := AssociativeArray();
	for i in [1..#cusps] do
	    K := cusps[i]`field;
	    PK := DefiningPolynomial(K);
	    is_defined, pts := IsDefined(cusp_coords, PK);
	    if not is_defined then
		cusp_coords[PK] := Points(cusp_scheme, K);
		field_idx[PK] := 1;
	    end if;				     
	    cusps[i]`coords := cusp_coords[PK][field_idx[PK]];
	    field_idx[PK] +:= 1;
	end for;
	return X, j, model_type, cusps;
    end if;
    // handling X(1)
    if IsEmpty(gens) then
	M := CreateModularCurveRec(level, gens);
	P1<x,y>:=Curve(ProjectiveSpace(Rationals(),1));
	_<q> := PowerSeriesRing(Rationals());
	M`F0 := [[jInvariant(q)]];
	M`psi := [CoordinateRing(P1) |];
	cusps := CuspOrbits(level, gens)[1];
	cusps[1]`coords := P1![1,0];
	// 1 is for P1 model
	return P1, FunctionField(P1).1, 1, cusps;
    end if;
     // Replacing this by Jeremy's new function
    X, j, model_type, F := FindJMap(level, gens);
    cusps := CuspOrbits(level, gens);
    // We only need one representative of each orbit
    cusps := [orb[1] : orb in cusps];
    for i in [1..#cusps] do
	CuspUpdateCoordinates(~cusps[i], X, F);
    end for;
    return X, j, model_type, cusps;
end intrinsic;
