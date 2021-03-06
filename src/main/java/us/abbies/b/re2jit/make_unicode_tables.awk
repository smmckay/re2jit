# Copyright 2011 Google Inc. All Rights Reserved.
# Author: adonovan@google.com (Alan Donovan)
#
# Generate Unicode range tables for RE2/Java.
#
# The JRE provides this information, but in the wrong direction.
# I.e., you can go from rune to class (category, scripts, properties)
# but not the other direction (given a class, list all the runes
# it contains). (This functionality is provided in Java by
# java.lang.Character).
#
# This script processes Go's version of these tables to convert
# them into a Java class with static members containing this information.
#
# Run like so:
# awk -f make_unicode_tables.awk go/src/pkg/unicode/tables.go \
#   >UnicodeTables.java
#
# States:
# 0 = toplevel
# 1 = inside Scripts/Categories/Properties definition:
#      var Categories = map[string]*RangeTable{
#        "Lm": Lm,
#        ...
#      }
# 2 = inside a range definition:
#      var _Carian = &RangeTable{
#        ...
#        R32: []Range32{
#                {0x102a0, 0x102d0, 1},
#                ...
#        },
#      }
# 3 = inside an alias definition:
#      var (
#         Cc = _Cc;  // comment
#         ...
#      )
# 4 = inside CaseRanges definition:
#      var _CaseRanges = []CaseRange{
#        {0x0041, 0x005A, d{0, 32, 0}},
#        ...
#      }
# 5 = inside caseOrbit definition:
#      var caseOrbit = []foldPair{
#        {0x004B, 0x006B},
#        ...
#      }

BEGIN {
  print "// AUTOGENERATED by make_unicode_tables.awk from the output of"
  print "// go/src/pkg/unicode/maketables.go.  Yes it's awful, but frankly"
  print "// it's quicker than porting 1300 more lines of Go."
  print
  print "package us.abbies.b.re2jit;";
  print
  print "import java.util.HashMap;"
  print "import java.util.Map;"
  print
  print "class UnicodeTables {";

  # Constants used by CASE_RANGES and by Unicode utilities.
  # TODO(adonovan): use Java-style identifiers.
  print "  static final int UpperCase = 0;";
  print "  static final int LowerCase = 1;";
  print "  static final int TitleCase = 2;";
  print "  static final int UpperLower = 0x110000;";
}


### State 1

state == 0 && /^var FoldScript = .*{}/ {
  # Special case for when this map is empty map
  print "  private static Map<String, int[][]> " $2 "() {";
  print "    return new HashMap<String, int[][]>();";
  print "  }";
  next;
}
state == 0 && /^var (Categories|Scripts|FoldCategory|FoldScript|Properties)/ {
  print "  private static Map<String, int[][]> "$2"() {";
  print "    Map<String, int[][]> map = new HashMap<String, int[][]>();";
  state = 1;
  next;
}
state == 1 && /.*: .*,/ {
  key = substr($1, 0, length($1) - 1);
  value = substr($2, 0, length($2) - 1);
  print "    map.put(" key ", " value ");";
  next;
}
state == 1 && /^}/ {
  print "    return map;"
  print "  }";
  state = 0;
  next;
}


### State 2

state == 0 && /^var .* = &RangeTable{/ {
  # Hack upon hack: javac refuses to compile too-large methods,
  # so we have to split this into smaller pieces.
  print "  private static final int[][] " $2 " = make" $2 "();";
  print "  private static int[][] make" $2 "() {";
  print "    return new int[][] {"
  state = 2;
  next;
}
state == 2 && / *R(16|32)/         { next; }
state == 2 && /\t},/               { next; }
state == 2 && /^}/ {
  print "    };";
  print "  }";
  state = 0;
  next;
}
state == 2                         { print; }


### State 3

state == 0 && /^var \(/ {
  state = 3;
  next;
}
state == 3 && /=/ {
  print "  static final int[][] " $1 " = " $3 ";";
}
state == 3 && /^)/ {
  state = 0;
  next;
}

### State 4

state == 0 && /^var _CaseRanges = / {
  print "  static final int[][] CASE_RANGES = {";
  state = 4;
  next;
}
state == 4 && /^}/ {
  state = 0;
  print "  };"
  next;
}
state == 4 {
  sub("d{", "");
  sub("}}", "}");
  print;
}

### State 5

state == 0 && /^var caseOrbit = / {
  print "  static final int[][] CASE_ORBIT = {";
  state = 5;
  next;
}
state == 5 && /^}/ {
  state = 0;
  print "  };"
  next;
}
state == 5 {
  print;
}


END {
  # Call the functions after all initialization has occurred.
  print "  static final Map<String, int[][]> CATEGORIES = Categories();"
  print "  static final Map<String, int[][]> SCRIPTS    = Scripts();"
  print "  static final Map<String, int[][]> PROPERTIES = Properties();"
  print "  static final Map<String, int[][]> FOLD_CATEGORIES = FoldCategory();"
  print "  static final Map<String, int[][]> FOLD_SCRIPT = FoldScript();"
  print ""
  print "  private UnicodeTables() {}  // uninstantiable";
  print "}"
}
