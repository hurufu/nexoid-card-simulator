#ifndef LOG_H
#define LOG_H

#include <stdlib.h>
#include <err.h>

#define LOG_X(Level, Prefix, Fmt, ...) (Level > g_log_level ? (void)0 : warnx(Prefix " %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__))
#define LOGF_(ErrFunction, Fmt, ...) (LOG_FATAL > g_log_level ? (void)0 : ErrFunction (EXIT_FAILURE, "F %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__))
#define LOGDX(Fmt, ...) LOG_X(LOG_DEBUG, "D", Fmt, ##__VA_ARGS__)
#define LOGIX(Fmt, ...) LOG_X(LOG_INFO, "I", Fmt, ##__VA_ARGS__)
#define LOGWX(Fmt, ...) LOG_X(LOG_WARNING, "W", Fmt, ##__VA_ARGS__)
#define LOGEX(Fmt, ...) LOG_X(LOG_ERROR, "E", Fmt, ##__VA_ARGS__)
#define LOGFX(Fmt, ...) LOGF_(errx, Fmt, ##__VA_ARGS__)
#define LOGF(Fmt, ...) LOGF_(err, Fmt, ##__VA_ARGS__)
#define LOGW(Fmt, ...) (LOG_WARNING > g_log_level ? (void)0 : warn("W %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__))

enum LogLevel { LOG_NONE, LOG_FATAL, LOG_ERROR, LOG_WARNING, LOG_INFO, LOG_DEBUG };

#endif // LOG_H
