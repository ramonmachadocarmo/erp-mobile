class NavItem {
  const NavItem({required this.path, required this.label});

  final String path;
  final String label;
}

class NavGroup {
  const NavGroup({required this.title, required this.items});

  final String title;
  final List<NavItem> items;
}

const navGroups = [
  NavGroup(
    title: 'Estoque',
    items: [
      NavItem(path: '/estoque/produtos', label: 'Produtos'),
      NavItem(path: '/estoque/categorias', label: 'Categorias'),
      NavItem(path: '/estoque/almoxarifados', label: 'Almoxarifados'),
      NavItem(path: '/estoque/montagem', label: 'Montagem'),
      NavItem(path: '/estoque/saldos', label: 'Saldos'),
    ],
  ),
  NavGroup(
    title: 'Vendas',
    items: [
      NavItem(path: '/vendas/pedidos', label: 'Pedidos'),
      NavItem(path: '/vendas/precos', label: 'Preços de venda'),
      NavItem(path: '/vendas/clientes', label: 'Clientes'),
    ],
  ),
  NavGroup(
    title: 'Compras',
    items: [
      NavItem(path: '/compras/orcamentos', label: 'Orçamentos'),
      NavItem(path: '/compras/pedidos', label: 'Pedidos'),
      NavItem(path: '/compras/fornecedores', label: 'Fornecedores'),
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
    title: 'Configurador',
    items: [
      NavItem(path: '/config/unidades', label: 'Unidades'),
      NavItem(path: '/config/pagamento', label: 'Pagamento'),
      NavItem(path: '/config/usuarios', label: 'Usuários'),
      NavItem(path: '/config/regras', label: 'Regras'),
    ],
  ),
];
