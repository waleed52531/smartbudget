/* Tests an APK's library in adb-owned scratch space; never opens app data. */
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
static int (*open_db)(const char *, sqlite3 **, int, const char *);
static int (*close_db)(sqlite3 *);
static int (*key_db)(sqlite3 *, const void *, int);
static int (*exec_sql)(sqlite3 *, const char *, void *, void *, char **);
static int (*prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **);
static int (*step)(sqlite3_stmt *);
static int (*finalize)(sqlite3_stmt *);
static long long (*column_int64)(sqlite3_stmt *, int);
static const unsigned char *(*column_text)(sqlite3_stmt *, int);

static void require(int condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "FAIL: %s\n", message);
    exit(1);
  }
}

static sqlite3 *connect_db(const char *path, const unsigned char *key, int flags) {
  sqlite3 *db = NULL;
  require(open_db(path, &db, flags, NULL) == 0, "Open disposable database");
  sqlite3_stmt *stmt = NULL;
  require(prepare(db, "PRAGMA cipher", -1, &stmt, NULL) == 0 &&
              step(stmt) == 100,
          "Encryption engine required; plaintext fallback rejected");
  finalize(stmt);
  require(exec_sql(db, "PRAGMA cipher='chacha20'", NULL, NULL, NULL) == 0,
          "Select test cipher");
  if (key) require(key_db(db, key, 32) == 0, "Set disposable key");
  return db;
}

int main(int argc, char **argv) {
  const char *prefix = "/data/local/tmp/smartbudget-cipher-probe-";
  require(argc == 3 && strncmp(argv[2], prefix, strlen(prefix)) == 0 &&
              strstr(argv[2], "..") == NULL,
          "Only generated adb scratch paths are permitted");
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  require(library != NULL, "Load APK-packaged SQLite library");
#define LOAD(variable, symbol)                                                  \
  variable = dlsym(library, symbol);                                            \
  require(variable != NULL, "Required SQLite/encryption symbol missing")
  LOAD(open_db, "sqlite3_open_v2");
  LOAD(close_db, "sqlite3_close_v2");
  LOAD(key_db, "sqlite3_key");
  LOAD(exec_sql, "sqlite3_exec");
  LOAD(prepare, "sqlite3_prepare_v2");
  LOAD(step, "sqlite3_step");
  LOAD(finalize, "sqlite3_finalize");
  LOAD(column_int64, "sqlite3_column_int64");
  LOAD(column_text, "sqlite3_column_text");
  unsigned char key[32];
  FILE *random = fopen("/dev/urandom", "rb");
  require(random && fread(key, 1, sizeof(key), random) == sizeof(key),
          "Generate ephemeral test key");
  fclose(random);
  int fd = open(argv[2], O_WRONLY | O_CREAT | O_EXCL, 0600);
  require(fd >= 0, "Refuse to overwrite an existing file");
  close(fd);
  sqlite3 *db = connect_db(argv[2], key, 2);
  require(exec_sql(db,
                   "CREATE TABLE synthetic_probe(value INTEGER NOT NULL);"
                   "INSERT INTO synthetic_probe VALUES(12345)",
                   NULL, NULL, NULL) == 0,
          "Create encrypted synthetic record");
  require(close_db(db) == 0, "Close encrypted writer");
  unsigned char header[16];
  FILE *file = fopen(argv[2], "rb");
  require(file && fread(header, 1, sizeof(header), file) == sizeof(header),
          "Read disposable header");
  fclose(file);
  require(memcmp(header, "SQLite format 3\0", sizeof(header)) != 0,
          "Reject plaintext file header");
  db = connect_db(argv[2], key, 1);
  sqlite3_stmt *stmt = NULL;
  require(prepare(db, "SELECT value FROM synthetic_probe", -1, &stmt, NULL) == 0 &&
              step(stmt) == 100 && column_int64(stmt, 0) == 12345,
          "Reopen with correct key");
  finalize(stmt);
  require(prepare(db, "PRAGMA integrity_check", -1, &stmt, NULL) == 0 &&
              step(stmt) == 100 && strcmp((const char *)column_text(stmt, 0), "ok") == 0,
          "Encrypted integrity check");
  finalize(stmt);
  close_db(db);
  key[0] ^= 0xff;
  for (int attempt = 0; attempt < 2; attempt++) {
    db = connect_db(argv[2], attempt == 0 ? key : NULL, 1);
    stmt = NULL;
    int result = prepare(db, "SELECT value FROM synthetic_probe", -1, &stmt, NULL);
    require(result == 26, "Incorrect/missing key must return SQLITE_NOTADB");
    if (stmt) finalize(stmt);
    close_db(db);
  }
  memset(key, 0, sizeof(key));
  dlclose(library);
  puts("PASS: APK engine encrypted creation/reopen/integrity and wrong/missing-key rejection");
  return 0;
}
