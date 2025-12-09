# tfapply.nvim

> [!WARNING]
> Early development - not production ready

A Neovim plugin for running OpenTofu / Terraform apply commands with an interactive plan review interface.

## Demo

https://github.com/user-attachments/assets/90e1b0da-63be-4117-aa23-f41625ad017a

## Features

- Interactive plan review with approval workflow
- Targeted apply for specific resources or files
- Maintains Terraform state lock during review
- Terminal-based execution with real TTY support

## Requirements

- Neovim >= 0.10
- Terraform CLI installed and available in PATH

## Installation

### Using lazy.nvim

```lua
{
  'marius/tfapply.nvim',
  config = function()
    require('tfapply').setup({
      -- Your configuration here
    })
  end,
}
```

### Using packer.nvim

```lua
use {
  'marius/tfapply.nvim',
  config = function()
    require('tfapply').setup()
  end
}
```

## Configuration

Here's the default configuration:

```lua
require('tfapply').setup({
  -- Terminal window configuration
  terminal = {
    -- Window size (fraction of editor size)
    width = 0.8,
    height = 0.8,
    -- Border style: 'single', 'double', 'rounded', 'solid', 'shadow'
    border = 'rounded',
    -- Close terminal automatically on successful apply
    auto_close = false,
    -- Delay before auto-closing (milliseconds)
    auto_close_delay = 2000,
    -- Number of lines to keep in scrollback buffer
    scrollback = 100000,
    -- Show helpful keybinding hints at the top
    show_hints = true,
  },

  -- Terraform configuration
  terraform = {
    -- Terraform binary path (uses 'terraform' from PATH by default)
    bin = 'terraform',
    -- Working directory (nil uses current file's directory)
    cwd = nil,
    -- Additional terraform apply arguments
    apply_args = {},
    -- Environment variables for terraform (nil inherits from Neovim)
    -- Example: { TF_VAR_region = 'us-west-2', AWS_PROFILE = 'dev' }
    env = nil,
  },

  -- Parser configuration
  parser = {
    -- Resource types to recognize
    resource_types = {
      'resource',
      'data',
      'module',
    },
  },

  -- Interactive apply mode configuration
  interactive = {
    -- Enable interactive plan review mode
    enabled = true,
    -- Require all resource blocks to be reviewed before approving
    require_review_all = true,
    -- Auto-collapse blocks when marked as reviewed
    auto_collapse_reviewed = true,
    -- Show unchanged attributes in resource blocks
    show_unchanged = false,
    -- Auto-expand all blocks on initial display
    auto_expand_all = false,
    -- Highlight reviewed items differently
    dim_reviewed = true,
  },
})
```

### Common Configurations

Auto-close terminal on success:
```lua
require('tfapply').setup({
  terminal = { auto_close = true, auto_close_delay = 3000 },
})
```

Custom terraform binary or working directory:
```lua
require('tfapply').setup({
  terraform = { bin = '/usr/local/bin/terraform', cwd = '/path/to/project' },
})
```

Disable interactive mode:
```lua
require('tfapply').setup({
  interactive = { enabled = false },
})
```

## Interactive Plan Review

The plugin intercepts Terraform's approval prompt and presents a structured review interface.

### Implementation

- Terraform runs in a real terminal using `termopen()` for proper TTY support
- A buffer monitor polls the terminal output for the approval prompt pattern
- When detected, a review UI is created on top of the terminal window
- The terminal job remains alive, maintaining the Terraform state lock
- User input (`yes`/`no`) is sent via `chansend()` to the waiting Terraform process

### Review UI Controls

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate resources |
| `Space` | Mark as reviewed |
| `Enter` | Expand/collapse |
| `A` | Approve and apply |
| `R` / `q` | Reject and cancel |

### Workflow

1. Run `:TfApply` (or `:TfApplyHover` / `:TfApplyFile`)
2. Terraform generates plan in terminal window
3. Review UI appears at approval prompt
4. Mark resources as reviewed, then approve or reject
5. Terminal window returns showing apply progress

## Commands

| Command | Description |
|---------|-------------|
| `:TfApply` | Apply terraform (full apply) |
| `:TfApplyHover` | Apply the resource under cursor (targeted apply) |
| `:TfApplyFile` | Apply all resources in the current file (targeted apply) |
| `:TfInit` | Run terraform init |
| `:TfApplyClose` | Close the terraform terminal window |

## Troubleshooting

Run `:checkhealth tfapply` to diagnose configuration issues.

## License

MIT
