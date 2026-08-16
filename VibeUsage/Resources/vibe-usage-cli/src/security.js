// The bundled collector writes only inside the app's dedicated data directory.
// Force owner-only permissions for every file/directory it creates, including
// parser caches and atomic temporary files.
if (process.platform !== 'win32') {
  process.umask(0o077);
}
