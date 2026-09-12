/*
** $Id: lundump.c $
** load precompiled Lua chunks
** See Copyright Notice in lua.h
*/

#define lundump_c
#define LUA_CORE

#include "lprefix.h"


#include <limits.h>
#include <string.h>

#include "lua.h"

#include "ldebug.h"
#include "ldo.h"
#include "lfunc.h"
#include "lmem.h"
#include "lobject.h"
#include "lopcodes.h"
#include "lstring.h"
#include "lundump.h"
#include "luaenc.h"
#include "lzio.h"


#if !defined(luai_verifycode)
#define luai_verifycode(L,f)  /* empty */
#endif


typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  int standard;  /* stock Lua 5.4 chunk; otherwise our salted VM format */
} LoadState;


static l_noret error (LoadState *S, const char *why) {
  luaO_pushfstring(S->L, "%s: bad binary format (%s)", S->name, why);
  luaD_throw(S->L, LUA_ERRSYNTAX);
}


/*
** All high-level loads go through loadVector; you can change it to
** adapt to the endianness of the input
*/
#define loadVector(S,b,n)	loadBlock(S,b,(n)*sizeof((b)[0]))

static void loadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0)
    error(S, "truncated chunk");
}


#define loadVar(S,x)		loadVector(S,&x,1)


static lu_byte loadByte (LoadState *S) {
  int b = zgetc(S->Z);
  if (b == EOZ)
    error(S, "truncated chunk");
  return cast_byte(b);
}


static size_t loadUnsigned (LoadState *S, size_t limit) {
  size_t x = 0;
  int b;
  limit >>= 7;
  do {
    b = loadByte(S);
    if (x >= limit)
      error(S, "integer overflow");
    x = (x << 7) | (b & 0x7f);
  } while ((b & 0x80) == 0);
  return x;
}


static size_t loadSize (LoadState *S) {
  return loadUnsigned(S, MAX_SIZET);
}


static int loadInt (LoadState *S) {
  return cast_int(loadUnsigned(S, INT_MAX));
}


static lua_Number loadNumber (LoadState *S) {
  lua_Number x;
  const unsigned char *m = luaEnc_constMask();
  unsigned char *p;
  int i;
  loadVar(S, x);
  /* 常量盐：与 ldump.c dumpNumber 对称还原 */
  p = (unsigned char *)&x;
  if (!S->standard)
    for (i = 0; i < (int)sizeof(x); i++) p[i] ^= m[i & 7];
  return x;
}


static lua_Integer loadInteger (LoadState *S) {
  lua_Integer x;
  const unsigned char *m = luaEnc_constMask();
  unsigned char *p;
  int i;
  loadVar(S, x);
  p = (unsigned char *)&x;
  if (!S->standard)
    for (i = 0; i < (int)sizeof(x); i++) p[i] ^= m[i & 7];
  return x;
}


/*
** Load a nullable string into prototype 'p'.
*/
static TString *loadStringN (LoadState *S, Proto *p) {
  lua_State *L = S->L;
  TString *ts;
  size_t size = loadSize(S);
  if (size == 0)  /* no string? */
    return NULL;
  else if (--size <= LUAI_MAXSHORTLEN) {  /* short string? */
    char buff[LUAI_MAXSHORTLEN];
    const unsigned char *m = luaEnc_constMask();
    size_t i;
    loadVector(S, buff, size);  /* load string into buffer */
    /* 常量盐：与 ldump.c dumpString 对称还原 */
    if (!S->standard)
      for (i = 0; i < size; i++) buff[i] ^= (char)m[i & 7];
    ts = luaS_newlstr(L, buff, size);  /* create string */
  }
  else {  /* long string */
    ts = luaS_createlngstrobj(L, size);  /* create string */
    setsvalue2s(L, L->top.p, ts);  /* anchor it ('loadVector' can GC) */
    luaD_inctop(L);
    loadVector(S, getlngstr(ts), size);  /* load directly in final place */
    {
      const unsigned char *m = luaEnc_constMask();
      unsigned char *p = (unsigned char *)getlngstr(ts);
      size_t i;
      if (!S->standard)
        for (i = 0; i < size; i++) p[i] ^= m[i & 7];
    }
    L->top.p--;  /* pop string */
  }
  luaC_objbarrier(L, p, ts);
  return ts;
}


/*
** Load a non-nullable string into prototype 'p'.
*/
static TString *loadString (LoadState *S, Proto *p) {
  TString *st = loadStringN(S, p);
  if (st == NULL)
    error(S, "bad format for constant string");
  return st;
}


/* Lua 5.4's public opcode order, independent of the private enum order.
** Only ABC instructions swap B/C: Bx, sBx, Ax and sJ share those bits
** as a single operand and must be preserved verbatim.
*/
static Instruction convertStandardInstruction (LoadState *S, Instruction i) {
  static const OpCode standardops[] = {
    OP_MOVE, OP_LOADI, OP_LOADF, OP_LOADK, OP_LOADKX,
    OP_LOADFALSE, OP_LFALSESKIP, OP_LOADTRUE, OP_LOADNIL,
    OP_GETUPVAL, OP_SETUPVAL, OP_GETTABUP, OP_GETTABLE, OP_GETI,
    OP_GETFIELD, OP_SETTABUP, OP_SETTABLE, OP_SETI, OP_SETFIELD,
    OP_NEWTABLE, OP_SELF, OP_ADDI, OP_ADDK, OP_SUBK, OP_MULK,
    OP_MODK, OP_POWK, OP_DIVK, OP_IDIVK, OP_BANDK, OP_BORK,
    OP_BXORK, OP_SHRI, OP_SHLI, OP_ADD, OP_SUB, OP_MUL, OP_MOD,
    OP_POW, OP_DIV, OP_IDIV, OP_BAND, OP_BOR, OP_BXOR, OP_SHL,
    OP_SHR, OP_MMBIN, OP_MMBINI, OP_MMBINK, OP_UNM, OP_BNOT,
    OP_NOT, OP_LEN, OP_CONCAT, OP_CLOSE, OP_TBC, OP_JMP, OP_EQ,
    OP_LT, OP_LE, OP_EQK, OP_EQI, OP_LTI, OP_LEI, OP_GTI, OP_GEI,
    OP_TEST, OP_TESTSET, OP_CALL, OP_TAILCALL, OP_RETURN,
    OP_RETURN0, OP_RETURN1, OP_FORLOOP, OP_FORPREP, OP_TFORPREP,
    OP_TFORCALL, OP_TFORLOOP, OP_SETLIST, OP_CLOSURE, OP_VARARG,
    OP_VARARGPREP, OP_EXTRAARG
  };
  unsigned int opcode = cast_uint(i & 0x7fu);
  OpCode mapped;
  if (opcode >= sizeof(standardops) / sizeof(standardops[0]))
    error(S, "invalid standard opcode");
  mapped = standardops[opcode];
  SET_OPCODE(i, mapped);
  if (getOpMode(mapped) == iABC) {
    unsigned int b = cast_uint((i >> 16) & 0xffu);
    unsigned int c = cast_uint((i >> 24) & 0xffu);
    SETARG_B(i, b);
    SETARG_C(i, c);
  }
  return i;
}


static void loadCode (LoadState *S, Proto *f) {
  int i;
  int n = loadInt(S);
  f->code = luaM_newvectorchecked(S->L, n, Instruction);
  f->sizecode = n;
  loadVector(S, f->code, n);
  for (i = 0; i < n; i++) {
    if (S->standard)
      f->code[i] = convertStandardInstruction(S, f->code[i]);
    else if (cast_uint(GET_OPCODE(f->code[i])) >= NUM_OPCODES)
      error(S, "invalid opcode");
  }
}


static void loadFunction(LoadState *S, Proto *f, TString *psource);


static void loadConstants (LoadState *S, Proto *f) {
  int i;
  int n = loadInt(S);
  f->k = luaM_newvectorchecked(S->L, n, TValue);
  f->sizek = n;
  for (i = 0; i < n; i++)
    setnilvalue(&f->k[i]);
  for (i = 0; i < n; i++) {
    TValue *o = &f->k[i];
    int t = loadByte(S);
    switch (t) {
      case LUA_VNIL:
        setnilvalue(o);
        break;
      case LUA_VFALSE:
        setbfvalue(o);
        break;
      case LUA_VTRUE:
        setbtvalue(o);
        break;
      case LUA_VNUMFLT:
        setfltvalue(o, loadNumber(S));
        break;
      case LUA_VNUMINT:
        setivalue(o, loadInteger(S));
        break;
      case LUA_VSHRSTR:
      case LUA_VLNGSTR:
        setsvalue2n(S->L, o, loadString(S, f));
        break;
      default: error(S, "invalid constant type");
    }
  }
}


static void loadProtos (LoadState *S, Proto *f) {
  int i;
  int n = loadInt(S);
  f->p = luaM_newvectorchecked(S->L, n, Proto *);
  f->sizep = n;
  for (i = 0; i < n; i++)
    f->p[i] = NULL;
  for (i = 0; i < n; i++) {
    f->p[i] = luaF_newproto(S->L);
    luaC_objbarrier(S->L, f, f->p[i]);
    loadFunction(S, f->p[i], f->source);
  }
}


/*
** Load the upvalues for a function. The names must be filled first,
** because the filling of the other fields can raise read errors and
** the creation of the error message can call an emergency collection;
** in that case all prototypes must be consistent for the GC.
*/
static void loadUpvalues (LoadState *S, Proto *f) {
  int i, n;
  n = loadInt(S);
  f->upvalues = luaM_newvectorchecked(S->L, n, Upvaldesc);
  f->sizeupvalues = n;
  for (i = 0; i < n; i++)  /* make array valid for GC */
    f->upvalues[i].name = NULL;
  for (i = 0; i < n; i++) {  /* following calls can raise errors */
    f->upvalues[i].instack = loadByte(S);
    f->upvalues[i].idx = loadByte(S);
    f->upvalues[i].kind = loadByte(S);
  }
}


static void loadDebug (LoadState *S, Proto *f) {
  int i, n;
  n = loadInt(S);
  f->lineinfo = luaM_newvectorchecked(S->L, n, ls_byte);
  f->sizelineinfo = n;
  loadVector(S, f->lineinfo, n);
  n = loadInt(S);
  f->abslineinfo = luaM_newvectorchecked(S->L, n, AbsLineInfo);
  f->sizeabslineinfo = n;
  for (i = 0; i < n; i++) {
    f->abslineinfo[i].pc = loadInt(S);
    f->abslineinfo[i].line = loadInt(S);
  }
  n = loadInt(S);
  f->locvars = luaM_newvectorchecked(S->L, n, LocVar);
  f->sizelocvars = n;
  for (i = 0; i < n; i++)
    f->locvars[i].varname = NULL;
  for (i = 0; i < n; i++) {
    f->locvars[i].varname = loadStringN(S, f);
    f->locvars[i].startpc = loadInt(S);
    f->locvars[i].endpc = loadInt(S);
  }
  n = loadInt(S);
  if (n != 0)  /* does it have debug information? */
    n = f->sizeupvalues;  /* must be this many */
  for (i = 0; i < n; i++)
    f->upvalues[i].name = loadStringN(S, f);
}


static void loadFunction (LoadState *S, Proto *f, TString *psource) {
  f->source = loadStringN(S, f);
  if (f->source == NULL)  /* no source in dump? */
    f->source = psource;  /* reuse parent's source */
  f->linedefined = loadInt(S);
  f->lastlinedefined = loadInt(S);
  f->numparams = loadByte(S);
  f->is_vararg = loadByte(S);
  f->maxstacksize = loadByte(S);
  loadCode(S, f);
  loadConstants(S, f);
  loadUpvalues(S, f);
  loadProtos(S, f);
  loadDebug(S, f);
}


static void checkliteral (LoadState *S, const char *s, const char *msg) {
  char buff[sizeof(LUA_SIGNATURE) + sizeof(LUAC_DATA)]; /* larger than both */
  size_t len = strlen(s);
  loadVector(S, buff, len);
  if (memcmp(s, buff, len) != 0)
    error(S, msg);
}


static void fchecksize (LoadState *S, size_t size, const char *tname) {
  if (loadByte(S) != size)
    error(S, luaO_pushfstring(S->L, "%s size mismatch", tname));
}


#define checksize(S,t)	fchecksize(S,sizeof(t),#t)

static void checkHeader (LoadState *S) {
  lua_Integer checkinteger;
  /* skip 1st char (already read and checked) */
  checkliteral(S, &LUA_SIGNATURE[1], "not a binary chunk");
  if (loadByte(S) != LUAC_VERSION)
    error(S, "version mismatch");
  if (loadByte(S) != LUAC_FORMAT)
    error(S, "format mismatch");
  checkliteral(S, LUAC_DATA, "corrupted chunk");
  checksize(S, Instruction);
  checksize(S, lua_Integer);
  checksize(S, lua_Number);
  /* Existing private chunks salt the header probes as well as constants.
  ** Detect the input once, before reading any strings or instructions.
  ** Keep dumping in the private format so existing encrypted assets and
  ** string.dump round trips retain their format.
  */
  loadVar(S, checkinteger);
  S->standard = (checkinteger == LUAC_INT);
  if (!S->standard) {
    const unsigned char *mask = luaEnc_constMask();
    unsigned char *bytes = (unsigned char *)&checkinteger;
    size_t i;
    for (i = 0; i < sizeof(checkinteger); i++) bytes[i] ^= mask[i & 7];
    if (checkinteger != LUAC_INT)
      error(S, "integer format mismatch");
  }
  if (loadNumber(S) != LUAC_NUM)
    error(S, "float format mismatch");
}


/*
** Load precompiled chunk.
*/
LClosure *luaU_undump(lua_State *L, ZIO *Z, const char *name) {
  LoadState S;
  LClosure *cl;
  if (*name == '@' || *name == '=')
    S.name = name + 1;
  else if (*name == LUA_SIGNATURE[0])
    S.name = "binary string";
  else
    S.name = name;
  S.L = L;
  S.Z = Z;
  checkHeader(&S);
  cl = luaF_newLclosure(L, loadByte(&S));
  setclLvalue2s(L, L->top.p, cl);
  luaD_inctop(L);
  cl->p = luaF_newproto(L);
  luaC_objbarrier(L, cl, cl->p);
  loadFunction(&S, cl->p, NULL);
  if (cl->nupvalues != cl->p->sizeupvalues)
    error(&S, "upvalue count mismatch");
  luai_verifycode(L, cl->p);
  return cl;
}

