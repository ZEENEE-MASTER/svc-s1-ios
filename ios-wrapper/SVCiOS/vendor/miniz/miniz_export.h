/* miniz_export.h — static-link stub (CMake would generate this).
 * miniz is compiled straight into the app: no shared-library visibility
 * macros needed. Matches GenerateExportHeader output for a static build. */
#ifndef MINIZ_EXPORT_H
#define MINIZ_EXPORT_H

#define MINIZ_EXPORT
#define MINIZ_NO_EXPORT

#ifndef MINIZ_DEPRECATED
#define MINIZ_DEPRECATED
#endif
#ifndef MINIZ_DEPRECATED_EXPORT
#define MINIZ_DEPRECATED_EXPORT MINIZ_EXPORT MINIZ_DEPRECATED
#endif
#ifndef MINIZ_DEPRECATED_NO_EXPORT
#define MINIZ_DEPRECATED_NO_EXPORT MINIZ_NO_EXPORT MINIZ_DEPRECATED
#endif

#endif /* MINIZ_EXPORT_H */
