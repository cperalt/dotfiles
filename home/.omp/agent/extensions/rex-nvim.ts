// rex.nvim omp side, loaded from ~/code/rex.nvim. Dynamic import because the
// checkout path depends on $HOME and this file is reached through a symlink.
import * as os from "node:os";
import * as path from "node:path";

const mod = await import(path.join(os.homedir(), "code/rex.nvim/omp/rex-nvim.ts"));
export default mod.default;
