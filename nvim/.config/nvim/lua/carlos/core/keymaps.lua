-- set leader key to space
vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------

-- use jk to exit insert
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader><Tab>o", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader><Tab>x", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader><Tab>n", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader><Tab>p", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
keymap.set("n", "<leader><Tab>f", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })
