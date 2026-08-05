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
  "GTI",
  "GEI",
  "TFORPREP",
  "LOADI",
  "SETTABLE",
  "TAILCALL",
  "TFORCALL",
  "TESTSET",
  "VARARG",
  "MOVE",
  "GETUPVAL",
  "SHLI",
  "EQ",
  "MMBIN",
  "CONCAT",
  "LOADTRUE",
  "GETI",
  "SETFIELD",
  "TEST",
  "SETUPVAL",
  "ADDK",
  "SUBK",
  "MULK",
  "MODK",
  "POWK",
  "DIVK",
  "IDIVK",
  "BANDK",
  "BORK",
  "BXORK",
  "LFALSESKIP",
  "VARARGPREP",
  "SELF",
  "LOADNIL",
  "GETTABUP",
  "TFORLOOP",
  "EQK",
  "CLOSURE",
  "ADDI",
  "TBC",
  "UNM",
  "BNOT",
  "NOT",
  "LEN",
  "CALL",
  "MMBINI",
  "LOADK",
  "GETFIELD",
  "SETTABUP",
  "ADD",
  "SUB",
  "MUL",
  "MOD",
  "POW",
  "DIV",
  "IDIV",
  "BAND",
  "BOR",
  "BXOR",
  "SHL",
  "SHR",
  "LT",
  "LE",
  "NEWTABLE",
  "EQI",
  "SETI",
  "FORPREP",
  "JMP",
  "LTI",
  "LEI",
  "RETURN",
  "LOADFALSE",
  "RETURN0",
  "GETTABLE",
  "SHRI",
  "CLOSE",
  "LOADKX",
  "FORLOOP",
  "SETLIST",
  "LOADF",
  "RETURN1",
  "MMBINK",
  "EXTRAARG",
  NULL
};

#endif

