# tfapply.nvim

A Neovim plugin that makes running Terraform apply easier and more efficient by providing targeted resource apply functionality directly from your editor.

## Features

- Full Terraform Apply - Run `terraform apply` in a floating terminal window
- Targeted Apply on Hover - Apply only the resource under your cursor
- File-Level Apply - Apply all resources in the current file
- Floating Terminal - Clean, customizable floating window for terraform output
- Smart Resource Detection - Automatically detects Terraform resources, data sources, and modules
- Configurable - Customize window size, borders, and more

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
      -- Your configuration here (optional)
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

### Using vim-plug

```vim
Plug 'marius/tfapply.nvim'

lua << EOF
require('tfapply').setup()
EOF
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

#### Environment variables for credentials

```lua
require('tfapply').setup({
  terraform = {
    env = {
      -- AWS credentials
      AWS_PROFILE = 'dev',
      AWS_REGION = 'us-west-2',

      -- Or explicit credentials
      -- AWS_ACCESS_KEY_ID = 'your-key',
      -- AWS_SECRET_ACCESS_KEY = 'your-secret',

      -- Terraform variables
      TF_VAR_environment = 'development',
      TF_VAR_region = 'us-west-2',

      -- Azure credentials
      -- ARM_SUBSCRIPTION_ID = 'your-subscription-id',
      -- ARM_CLIENT_ID = 'your-client-id',

      -- GCP credentials
      -- GOOGLE_APPLICATION_CREDENTIALS = '/path/to/credentials.json',
    },
  },
})
```

#### Loading from external file or function

```lua
require('tfapply').setup({
  terraform = {
    env = vim.fn.environ(),  -- Use all current shell environment
    -- Or load from a file
    -- env = loadfile(vim.fn.expand('~/.terraform-env.lua'))(),
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

## Terminal Keybindings

When the terraform terminal is open:

### Terminal Mode (default)
| Key | Action |
|-----|--------|
| `Ctrl+N` | Enter normal mode for scrolling |
| `Ctrl+Q` | Quick close terminal |

### Normal Mode (for scrolling/reading)
| Key | Action |
|-----|--------|
| `q` or `ESC` | Close terminal |
| `Ctrl+D` / `Ctrl+U` | Scroll down/up half page |
| `Ctrl+F` / `Ctrl+B` | Scroll down/up full page |
| `G` / `gg` | Jump to bottom/top |
| `i`, `a`, `A` | Return to terminal mode at bottom |
| Mouse scroll | Scroll up/down |

## Usage Examples

### Basic Usage

1. Open a Terraform file (`.tf`)
2. Position your cursor on a resource:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

3. Run `:TfApplyHover` to apply only this resource
4. The command will execute: `terraform apply -target=resource.aws_instance.example`

### Apply All Resources in File

If you have a file with multiple resources:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

resource "aws_security_group" "web_sg" {
  name = "web_sg"
}

data "aws_ami" "ubuntu" {
  most_recent = true
}
```

Run `:TfApplyFile` to target all resources in the current file.

### Keybindings (Optional)

Add these to your Neovim configuration for quick access:

```lua
vim.keymap.set('n', '<leader>ta', ':TfApply<CR>', { desc = 'Terraform Apply' })
vim.keymap.set('n', '<leader>th', ':TfApplyHover<CR>', { desc = 'Terraform Apply Hover' })
vim.keymap.set('n', '<leader>tf', ':TfApplyFile<CR>', { desc = 'Terraform Apply File' })
vim.keymap.set('n', '<leader>tq', ':TfApplyClose<CR>', { desc = 'Terraform Close Terminal' })
```

## Supported Resource Types

The plugin automatically detects and can target:

- Resources: `resource "type" "name"`
- Data Sources: `data "type" "name"`
- Modules: `module "name"`

## Health Check

Run `:checkhealth tfapply` to verify:

- Neovim version compatibility
- Terraform installation
- Configuration validity
- Current project state

## How It Works

1. Resource Detection: The plugin parses your Terraform file to identify resource blocks
2. Smart Targeting: When you run `:TfApplyHover`, it:
   - Finds the resource block containing your cursor
   - Extracts the resource address (e.g., `resource.aws_instance.example`)
   - Runs `terraform apply -target=<address>`
3. Floating Terminal: Opens a clean terminal window to show terraform output
4. Exit Handling: Automatically detects success/failure and notifies you

## Tips

- Use `:TfApplyHover` for quick iterations on specific resources
- Use `:TfApplyFile` when working on related resources in the same file
- Use `:TfApply` for full applies when ready to deploy everything
- The terminal window can be closed with `q` or `<ESC>` in normal mode
- Set environment variables in the config for credentials instead of hardcoding in files
- Use AWS_PROFILE or similar mechanisms for credential management

## Troubleshooting

### "Terraform binary not found"

Make sure Terraform is installed and in your PATH:

```bash
which terraform
terraform version
```

Or set the full path in configuration:

```lua
require('tfapply').setup({
  terraform = {
    bin = '/full/path/to/terraform',
  },
})
```

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
