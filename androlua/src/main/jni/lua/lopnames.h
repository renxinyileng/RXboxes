/*
** $Id: lopnames.h $
** Opcode names
** See Copyright Notice in lua.h
*/

#if !defined(lopnames_h)
#define lopnames_h

#include <stddef.h>


/* ORDER OP */

static const char *const opnames[] = {
  "GETFIELD",
  "NEWTABLE",
  "LEN",
  "SELF",
  "EQK",
  "MODK",
  "TFORPREP",
  "SHR",
  "LT",
  "LOADKX",
  "SETUPVAL",
  "GTI",
  "GETTABLE",
  "BXORK",
  "GETUPVAL",
  "BORK",
  "SETI",
  "SUB",
  "UNM",
  "BAND",
  "MMBIN",
  "TEST",
  "SHLI",
  "SUBK",
  "FORPREP",
  "TBC",
  "CLOSURE",
  "DIVK",
  "VARARGPREP",
  "LOADTRUE",
  "EQI",
  "BNOT",
  "RETURN0",
  "BXOR",
  "SETTABUP",
  "POWK",
  "RETURN1",
  "SETLIST",
  "GETI",
  "GETTABUP",
  "SHL",
  "LOADI",
  "CONCAT",
  "POW",
  "JMP",
  "DIV",
  "IDIVK",
  "SHRI",
  "MOVE",
  "MULK",
  "LOADF",
  "MMBINK",
  "TFORCALL",
  "BANDK",
  "LE",
  "ADD",
  "MUL",
  "RETURN",
  "VARARG",
  "CLOSE",
  "TESTSET",
  "LOADFALSE",
  "LTI",
  "CALL",
  "LEI",
  "SETFIELD",
  "IDIV",
  "BOR",
  "LOADK",
  "LFALSESKIP",
  "NOT",
  "MMBINI",
  "TFORLOOP",
  "FORLOOP",
  "LOADNIL",
  "ADDK",
  "MOD",
  "EQ",
  "TAILCALL",
  "ADDI",
  "SETTABLE",
  "GEI",
  "EXTRAARG",
  NULL
};

#endif

