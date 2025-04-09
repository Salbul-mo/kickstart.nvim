local M = {}

function M.setup()
  M.setup_jdtls()

  require('dap_config').setup()
end

function M.setup_jdtls()
  local home = os.getenv 'JAVA_HOME'

  local jdtls = require 'jdtls'

  local root_markers = {
    '.git',
    'mvnw',
    'gradlew',
    'pom.xml',
    'build.gradle',
    '.project',
  }

  local root_dir = require('jdtls.setup').find_root(root_markers)

  if root_dir == '' then
    return
  end

  local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
  local workspace_dir = home .. '/.cache/jdtls/workspace/' .. project_name

  os.execute('mkdir -p ' .. workspace_dir)

  local mason_registry = require 'mason-registry'
  local jdtls_path = ''
  if mason_registry.is_installed 'jdtls' then
    jdtls_path = mason_registry.get_package('jdtls'):get_install_path()
  end

  local os_config = 'config_win'
  if vim.fn.has 'mac' == 1 then
    os_config = 'config_mac'
  elseif vim.fn.has 'unix' == 1 then
    os_config = 'config_linux'
  end

  local bundles = {}

  local java_debug_path = home .. '/.vscode/extensions/vscjava.vscode-java-debug*/server/'
  local java_debug_bundle = vim.fn.glob(java_debug_path .. 'com.microsoft.java.debug.plugin-*.jar', true)
  if java_debug_bundle ~= '' then
    table.insert(bundles, java_debug_bundle)
  end

  local java_test_path = home .. '/.vscode/extentions/vscjava.vscode-java-test*/server/'
  local java_test_bundle = vim.fn.glob(java_test_path .. '*.jar', true)
  if java_test_bundle ~= '' then
    vim.list_extend(bundles, vim.split(java_test_bundle, '\n'))
  end

  local function on_attach(client, bufnr)
    local opts = { noremap = true, silent = true, buffer = bufnr }

    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action.opts)
    vim.keymap.set('n', '<leader>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)

    vim.keymap.set('n', '<leader>oi', jdtls.organize_imports, opts)
    vim.keymap.set('n', '<leader>ev', jdtls.extract_variable, opts)
    vim.keymap.set('v', '<leader>ev', function()
      jdtls.extract_variable(true)
    end, opts)
    vim.keymap.set('n', '<leader>ec', jdtls.extract_constant, opts)
    vim.keymap.set('v', '<leader>ec', function()
      jdtls.extract_constant(true)
    end, opts)
    vim.keymap.set('v', '<leader>em', function()
      jdtls.extract_method(true)
    end, opts)

    vim.keymap.set('n', '<leader>tc', jdtls.test_class, opts)
    vim.keymap.set('n', '<leader>tm', jdtls.test_nearest_method, opts)

    vim.keymap.set('n', '<leader>df', function()
      jdtls.test_class()
    end, opts)
    vim.keymap.set('n', '<leader>dn', function()
      jdtls.test_nearest_method()
    end, opts)

    require('jdtls').setup_dap { hotcodereplace = 'auto' }
    require('jdtls.dap').setup_dap_main_class_configs()

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -- local jdtls_path = vim.fn.stdpath 'data' .. '/mason/packages/jdtls'
    -- local config_path = jdtls_path .. '/config_win' -- Windows
    -- -- local config_path = jdtls_path .. '/config_linux' -- Linux
    -- -- macOS : local config_path = jdtls_path .. '/config_mac'
    --
    -- local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
    -- local workspace_dir = vim.fn.expand '~/.cache/jdtls-workspace/' .. project_name
    --
    -- -- Search for java runtime
    -- local java_home = os.getenv 'JAVA_HOME'
    -- local java_cmd = java_home and (java_home .. '/bin/java') or 'java'

    local config =
      {
        cmd = {
          'java',
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.level=ALL',
          '-Xmx1g',
          '--add-modules=ALL-SYSTEM',
          '--add-opens',
          'java.base/java.util=ALL-UNNAMED',
          '--add-opens',
          'java.base/java.lang=ALL-UNNAMED',
          '-jar',
          vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar'),
          '-configuration',
          jdtls_path .. '/' .. os_config,
          '-data',
          workspace_dir,
        },

        root_dir = root_dir,

        init_options = {
          bundles = bundles,
          extendedClientCapabilities = {
            progressReportProvider = true,
            classFileContentsSupport = true,
            resolveAdditionalTextEditsSupport = true,
            advancedExtractRefactoringSupport = true,
            advancedOrganizeImportsSupport = true,
            generateConstrunctorsPromptSupport = true,
            generateDelegateMethodPromptSupport = true,
            moveRefactoringSupport = true,
            overrideMehodsPromptSupport = true,
            hashCodeEqualsPromptSupport = true,
            advancedGenerateAccessorsSupport = true,
          },
        },

        -- Default Setting
        settings = {
          java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = 'fernflower' },
            importOrder = {
              'java',
              'javax',
              'com',
              'org',
            },
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
            codeGeneration = {
              toString = {
                template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
              },
              hashCodeEquals = {
                useJava7Objects = true,
              },
              useBlocks = true,
            },

            configuration = {
              updateBuildConfiguration = 'interactive',
            },
            maven = {
              downloadSources = true,
            },
            implementationsCodeLens = {
              enabled = true,
            },
            referencesCodeLens = {
              enabled = true,
            },
            references = {
              includeDecompiledSources = true,
            },
            inlayHints = {
              parameterNames = {
                enabled = 'all',
              },
              format = {
                enabled = true,
                settings = {
                  url = jdtls_path .. '/formatter.xml',
                  profile = 'GoogleStyle',
                },
              },
              completion = {
                favoriteStaticMembers = {
                  'org.junit.Assert.*',
                  'org.junit.Assume.*',
                  'org.junit.jupiter.api.Assertions.*',
                  'org.junit.jupiter.api.Assumptions.*',
                  'org.junit.jupiter.api.DynamicContainer.*',
                  'org.junit.jupiter.api.DynamicTest.*',
                  'org.mockito.Mockito.*',
                  'org.mockito.ArgumentMatchers.*',
                },
                filteredTypes = {
                  'com.sun.*',
                  'io.micrometer.shaded.*',
                  'java.awt.*',
                  'jdk.*',
                  'sun.*',
                },
              },
            },
          },

          -- LSP Initialize options
          --   init_options = {
          --     bundles = {
          --       --     vim.fn.glob('~/.local/share/nvim/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar', true),
          --       --     vim.fn.glob('~/.local/share/nvim/vscode-java-test/server/*.jar', true),
          --     },
          --   },
          -- }
          --
          -- local bundles = {
          --   vim.fn.glob('~/.local/share/nvim/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar', true),
          -- }
          --
          -- local vscode_java_test = vim.fn.glob('~/.local/share/nvim/vscode-java-test/server/*.jar', true)
          -- if vscode_java_test ~= '' then
          --   vim.list_extend(bundles, vim.split(vscode_java_test, '\n'))
          -- end
          --
          -- config.init_options = {
          --   bundles = bundles,
          -- }
          --
          capabilities = capabilities,
          on_attach = on_attach,
          flags = {
            allow_incremental_sync = true,
          },
        },
      }, jdtls.start_or_attach(config)
  end
  -- Start nvim-jdtls
  -- require('jdtls').start_or_attach(config)
  -- -- Optional : useful Key binding for java
  -- vim.keymap.set('n', '<A-o>', function()
  --   require('jdtls').organize_imports()
  -- end, { desc = 'Organize imports' })
  -- vim.keymap.set('n', 'crv', function()
  --   require('jdtls').extract_variable()
  -- end, { desc = 'Extract variable' })
  -- vim.keymap.set('v', 'crv', function()
  --   require('jdtls').extract_variable(true)
  -- end, { desc = 'Extract variable' })
  -- vim.keymap.set('n', 'crc', function()
  --   require('jdtls').extract_constant()
  -- end, { desc = 'Extract constant' })
  -- vim.keymap.set('v', 'crc', function()
  --   require('jdtls').extract_constant(true)
  -- end, { desc = 'Extract constant' })
  -- vim.keymap.set('v', 'crm', function()
  --   require('jdtls').extract_method(true)
  -- end, { desc = 'Extract method' })
end
return M
