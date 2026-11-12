-- return {
--   "rmagatti/auto-session",
--   lazy = false,
--
--   ---enables autocomplete for opts
--   ---@module "auto-session"
--   ---@type AutoSession.Config
--   opts = {
--     suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
--     -- log_level = 'debug',
--   },
-- }

return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore_enabled = false,
      auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
      -- Don't register the Telescope extension at startup; it forces Telescope
      -- to load eagerly. :SessionSearch still loads the picker on demand.
      session_lens = { load_on_setup = false },
    })

    local keymap = vim.keymap

    keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" }) -- restore last workspace session for current directory
    keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
  end,
}
