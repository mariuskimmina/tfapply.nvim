# tfapply.nvim

> [!WARNING]
> This is still early in development and not meant to be used in production, yet.

A Neovim plugin that makes running Terraform apply easier and more efficient by providing targeted resource apply functionality directly from your editor.

## Features

- Full Terraform Apply - Run `terraform apply` in a floating terminal window
- Targeted Apply on Hover - Apply only the resource under your cursor
- File-Level Apply - Apply all resources in the current file

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
})
```

### Example Configurations

#### Auto-close on success

```lua
require('tfapply').setup({
  terminal = {
    auto_close = true,
    auto_close_delay = 3000, -- 3 seconds
  },
})
```

#### Custom terraform binary or working directory

```lua
require('tfapply').setup({
  terraform = {
    bin = '/usr/local/bin/terraform',
    cwd = '/path/to/terraform/project',
  },
})
```

#### Environment variables

```lua
require('tfapply').setup({
  terraform = {
    env = {
      AWS_PROFILE = 'dev',
      AWS_REGION = 'us-west-2',
    },
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:TfApply` | Apply terraform (full apply) |
| `:TfApplyHover` | Apply the resource under cursor (targeted apply) |
| `:TfApplyFile` | Apply all resources in the current file (targeted apply) |
| `:TfApplyClose` | Close the terraform terminal window |


### Plugin not loading

Run `:checkhealth tfapply` to diagnose issues.

## Roadmap

Future features being considered:

- Visual selection mode to select multiple resources
- Terraform plan support
- Terraform destroy with targeting
- Integration with terraform state commands
- Resource dependency graph visualization
- Support for terraform workspaces

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details
