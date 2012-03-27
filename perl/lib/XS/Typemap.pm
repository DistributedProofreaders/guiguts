package XS::Typemap;

use base qw/ DynaLoader Exporter /;


use vars qw/ $VERSION @EXPORT /;

$VERSION = '0.01';

@EXPORT = (qw/
	   T_SV
	   T_SVREF
	   T_AVREF
	   T_HVREF
	   T_CVREF
	   T_SYSRET_fail T_SYSRET_pass
	   T_UV
	   T_IV
	   T_INT
           T_ENUM
           T_BOOL
           T_U_INT
           T_SHORT
           T_U_SHORT
           T_LONG
           T_U_LONG
           T_CHAR
           T_U_CHAR
           T_FLOAT
           T_NV
	   T_DOUBLE
	   T_PV
	   T_PTR_IN T_PTR_OUT
	   T_PTRREF_IN T_PTRREF_OUT
	   T_REF_IV_REF
	   T_REF_IV_PTR_IN T_REF_IV_PTR_OUT
	   T_PTROBJ_IN T_PTROBJ_OUT
	   T_OPAQUE_IN T_OPAQUE_OUT T_OPAQUE_array
	   T_OPAQUEPTR_IN T_OPAQUEPTR_OUT T_OPAQUEPTR_OUT_short
           T_OPAQUEPTR_IN_struct T_OPAQUEPTR_OUT_struct
	   T_ARRAY
	   T_STDIO_open T_STDIO_close T_STDIO_print
	   /);


bootstrap XS::Typemap;


1;

