class NavItem {
  const NavItem({required this.path, required this.label, String? menuKey})
      : menuKey = menuKey ?? path;

  final String path;
  final String label;

  /// Key the identity service stores per role (`role_menu_permissions`). It is
  /// the web menu route, which differs from [path] for a few mobile screens.
  final String menuKey;
}

class NavGroup {
  const NavGroup({required this.title, required this.items});

  final String title;
  final List<NavItem> items;
}

const navGroups = [
  NavGroup(
    title: 'PDV',
    items: [
      NavItem(path: '/pdv/pedidos', label: 'Pedidos'),
    ],
  ),
  NavGroup(
    title: 'Estoque',
    items: [
      NavItem(path: '/estoque/produtos', label: 'Produtos', menuKey: '/producao/produtos'),
      NavItem(path: '/estoque/categorias', label: 'Categorias', menuKey: '/producao/categorias'),
      NavItem(path: '/estoque/almoxarifados', label: 'Almoxarifados'),
      NavItem(path: '/estoque/montagem', label: 'Montagem', menuKey: '/producao/montagem'),
      NavItem(path: '/estoque/saldos', label: 'Saldos'),
    ],
  ),
  NavGroup(
    title: 'Vendas',
    items: [
      NavItem(path: '/vendas/pedidos', label: 'Pedidos'),
      NavItem(path: '/vendas/precos', label: 'Preços de venda'),
      NavItem(path: '/vendas/clientes', label: 'Clientes', menuKey: '/config/cadastros/clientes'),
    ],
  ),
  NavGroup(
    title: 'Compras',
    items: [
      NavItem(path: '/compras/orcamentos', label: 'Orçamentos'),
      NavItem(path: '/compras/pedidos', label: 'Pedidos'),
      NavItem(path: '/compras/fornecedores', label: 'Fornecedores', menuKey: '/config/cadastros/fornecedores'),
      NavItem(path: '/compras/historico', label: 'Histórico'),
    ],
  ),
  NavGroup(
    title: 'Logística',
    items: [
      NavItem(path: '/logistica/entrada', label: 'Entrada'),
      NavItem(path: '/logistica/conferencia', label: 'Conferência'),
      NavItem(path: '/logistica/separacao', label: 'Separação'),
      NavItem(path: '/logistica/rotas', label: 'Rotas'),
      NavItem(path: '/logistica/entrega', label: 'Entrega'),
    ],
  ),
  NavGroup(
    title: 'Ativos',
    items: [
      NavItem(path: '/ativos/bens', label: 'Bens'),
      NavItem(path: '/ativos/movimentos', label: 'Movimentações'),
    ],
  ),
  NavGroup(
    title: 'Fluxo de caixa',
    items: [
      NavItem(path: '/caixa/resumo', label: 'Por dia'),
      NavItem(path: '/caixa/lancamentos', label: 'Lançamentos'),
    ],
  ),
  NavGroup(
    title: 'Fiscal',
    items: [
      NavItem(path: '/fiscal/saida', label: 'Nota de saída'),
      NavItem(path: '/fiscal/entrada', label: 'Nota de entrada'),
    ],
  ),
  NavGroup(
    title: 'BI',
    items: [
      NavItem(path: '/bi/previsao', label: 'Previsão de vendas'),
      NavItem(path: '/bi/estoque', label: 'Plano de estoque'),
      NavItem(path: '/bi/orcamentos', label: 'Orçamentos'),
      NavItem(path: '/bi/precos', label: 'Preços de fornecedores'),
      NavItem(path: '/bi/financeiro', label: 'Receita x Despesa'),
      NavItem(path: '/bi/agendamentos', label: 'Agendamentos'),
    ],
  ),
  NavGroup(
    title: 'Relatórios',
    items: [
      NavItem(path: '/relatorios/kits', label: 'Kits'),
      NavItem(path: '/relatorios/estoque', label: 'Estoque de produtos'),
      NavItem(path: '/relatorios/vendas', label: 'Pedidos de venda'),
      NavItem(path: '/relatorios/compras', label: 'Pedidos de compra'),
      NavItem(path: '/relatorios/previsao', label: 'Previsão'),
    ],
  ),
  NavGroup(
    title: 'Configurador',
    items: [
      NavItem(path: '/config/unidades', label: 'Unidades', menuKey: '/config/cadastros/unidades'),
      NavItem(path: '/config/pagamento', label: 'Pagamento', menuKey: '/config/cadastros/pagamento'),
      NavItem(path: '/config/usuarios', label: 'Usuários', menuKey: '/config/cadastros/usuarios'),
      NavItem(path: '/config/perfis', label: 'Perfis', menuKey: '/config/cadastros/perfis'),
      NavItem(path: '/config/regras', label: 'Regras'),
    ],
  ),
];

/// Every menu the role matrix can grant, mirroring `MENU` in
/// `apps/web/packages/shared/src/menu.ts` (keep in sync). Profiles apply to web
/// and mobile alike, so this includes screens the app does not render.
const menuCatalog = <NavGroup>[
  NavGroup(title: 'PDV', items: [
    NavItem(path: '/pdv/pesagem', label: 'Pesagem'),
    NavItem(path: '/pdv/pedidos', label: 'Pedidos'),
  ]),
  NavGroup(title: 'Gestão de produtos', items: [
    NavItem(path: '/producao/categorias', label: 'Categorias'),
    NavItem(path: '/producao/produtos', label: 'Produtos'),
    NavItem(path: '/producao/montagem', label: 'Montagem'),
    NavItem(path: '/producao/pesagem', label: 'Pesagem'),
  ]),
  NavGroup(title: 'Estoque', items: [
    NavItem(path: '/estoque/almoxarifados', label: 'Almoxarifados'),
    NavItem(path: '/estoque/saldos', label: 'Saldos'),
    NavItem(path: '/estoque/movimentos', label: 'Movimentos'),
    NavItem(path: '/estoque/pesagem-kits', label: 'Pesagem de kits'),
  ]),
  NavGroup(title: 'Vendas', items: [
    NavItem(path: '/vendas/pedidos', label: 'Pedidos'),
    NavItem(path: '/vendas/precos', label: 'Preços de venda'),
  ]),
  NavGroup(title: 'Compras', items: [
    NavItem(path: '/compras/orcamentos', label: 'Orçamentos'),
    NavItem(path: '/compras/pedidos', label: 'Pedidos'),
    NavItem(path: '/compras/historico', label: 'Histórico'),
  ]),
  NavGroup(title: 'Logística', items: [
    NavItem(path: '/logistica/entrada', label: 'Entrada'),
    NavItem(path: '/logistica/conferencia', label: 'Conferência'),
    NavItem(path: '/logistica/separacao', label: 'Separação'),
    NavItem(path: '/logistica/rotas', label: 'Rotas'),
    NavItem(path: '/logistica/entrega', label: 'Entrega'),
  ]),
  NavGroup(title: 'Ativos', items: [
    NavItem(path: '/ativos/bens', label: 'Cadastro'),
    NavItem(path: '/ativos/movimentos', label: 'Movimentações'),
  ]),
  NavGroup(title: 'Fluxo de caixa', items: [
    NavItem(path: '/caixa/resumo', label: 'Por dia'),
    NavItem(path: '/caixa/lancamentos', label: 'Lançamentos'),
    NavItem(path: '/caixa/novo', label: 'Novo lançamento'),
  ]),
  NavGroup(title: 'Fiscal', items: [
    NavItem(path: '/fiscal/saida', label: 'Nota de saída'),
    NavItem(path: '/fiscal/entrada', label: 'Nota de entrada'),
  ]),
  NavGroup(title: 'Inteligência de Negócio', items: [
    NavItem(path: '/bi/previsao', label: 'Previsão de vendas'),
    NavItem(path: '/bi/estoque', label: 'Plano de estoque'),
    NavItem(path: '/bi/orcamentos', label: 'Orçamentos'),
    NavItem(path: '/bi/precos', label: 'Preços de fornecedores'),
    NavItem(path: '/bi/financeiro', label: 'Receita x Despesa'),
    NavItem(path: '/bi/agendamentos', label: 'Agendamentos'),
  ]),
  NavGroup(title: 'Relatórios', items: [
    NavItem(path: '/relatorios/kits', label: 'Kits'),
    NavItem(path: '/relatorios/estoque', label: 'Estoque de produtos'),
    NavItem(path: '/relatorios/vendas', label: 'Pedidos de venda'),
    NavItem(path: '/relatorios/compras', label: 'Pedidos de compra'),
    NavItem(path: '/relatorios/previsao', label: 'Previsão'),
  ]),
  NavGroup(title: 'Configurador', items: [
    NavItem(path: '/config/regras', label: 'Regras'),
    NavItem(path: '/config/empresa', label: 'Empresa'),
    NavItem(path: '/config/auditoria', label: 'Auditoria'),
    NavItem(path: '/config/cadastros/unidades', label: 'Unidades'),
    NavItem(path: '/config/cadastros/clientes', label: 'Clientes'),
    NavItem(path: '/config/cadastros/fornecedores', label: 'Fornecedores'),
    NavItem(path: '/config/cadastros/centros', label: 'Centros de distribuição'),
    NavItem(path: '/config/cadastros/veiculos', label: 'Veículos'),
    NavItem(path: '/config/cadastros/pagamento', label: 'Pagamento'),
    NavItem(path: '/config/cadastros/perfis', label: 'Perfis'),
    NavItem(path: '/config/cadastros/usuarios', label: 'Usuários'),
  ]),
];

/// Coarse, backend-enforced modules (gateway routes by these). Mirrors
/// `MODULES` / `MODULE_LABELS` in the web `menu.ts`.
const accessModules = <(String, String)>[
  ('identity', 'Identidade e usuários'),
  ('config', 'Configurador'),
  ('stock', 'Estoque e produção'),
  ('sales', 'Vendas e logística'),
  ('purchasing', 'Compras'),
  ('assets', 'Ativos'),
  ('cashflow', 'Fluxo de caixa'),
  ('invoicing', 'Fiscal'),
  ('bi', 'Inteligência de Negócio'),
  ('reports', 'Relatórios'),
  ('audit', 'Auditoria'),
];
