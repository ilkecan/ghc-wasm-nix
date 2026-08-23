import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

const modulePath = process.argv[2];
const wasi = new WASI({
  version: "preview1",
  args: [modulePath],
  returnOnExit: false,
});
const bytes = await readFile(modulePath);
const { instance } = await WebAssembly.instantiate(bytes, wasi.getImportObject());

wasi.start(instance);
