import 'package:flutter/material.dart';
import '../models/lottery_data.dart';
import '../services/lottery_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class LotteryScreen extends StatefulWidget {
  final String? title;
  const LotteryScreen({super.key, this.title});

  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> with SingleTickerProviderStateMixin {
  LotterySnapshot? _snapshot;
  bool _loading = false;
  late TabController _tabController;

  LotteryService get _service => getIt<LotteryService>();

  @override
  void initState() {
    super.initState();
    _snapshot = _service.getCached();
    _tabController = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await _service.fetch();
    if (mounted) {
      setState(() {
        if (data != null) _snapshot = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '복권 확률'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '스피또2000'),
            Tab(text: '스피또1000'),
            Tab(text: '스피또500'),
          ],
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGameTab('SP2000', theme),
                _buildGameTab('SP1000', theme),
                _buildGameTab('SP500', theme),
              ],
            ),
    );
  }

  Widget _buildGameTab(String typeCode, ThemeData theme) {
    final games = _snapshot?.games.where((g) => g.typeCode == typeCode).toList() ?? [];
    if (games.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        itemBuilder: (context, index) => _buildGameCard(games[index], theme),
      ),
    );
  }

  Widget _buildGameCard(ScratchGame game, ThemeData theme) {
    final remaining = game.estimatedRemainingTickets;
    final returnRate = game.returnRate;
    final ev = game.expectedValue;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 회차 + 판매기간
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${game.round}회',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatDate(game.saleStart)} ~ ${_formatDate(game.saleEnd)}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 요약: 기대값 + 환급률
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: returnRate >= 60
                    ? AppColors.success.withOpacity(0.08)
                    : returnRate >= 50
                        ? AppColors.warning.withOpacity(0.08)
                        : AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('기대값', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '${ev >= 0 ? '+' : ''}${ev.round()}원',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ev >= 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('환급률', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '${returnRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: returnRate >= 60 ? AppColors.success : returnRate >= 50 ? AppColors.warning : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('당첨 확률', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          game.currentWinProbability > 0
                              ? '1/${(1 / game.currentWinProbability).toStringAsFixed(1)}'
                              : '-',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 등수별 상세
            ...game.tiers.map((tier) => _buildTierRow(tier, remaining, theme)),

            // 갱신일
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.update, size: 12, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  '갱신: ${game.updateDate}  |  재고율: ${game.stockRate.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(PrizeTier tier, double totalTickets, ThemeData theme) {
    final prob = tier.probability(totalTickets);
    final remainRatio = tier.total > 0 ? tier.remaining / tier.total : 0.0;
    final isHighlight = tier.rank <= 2 && tier.remaining > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              // 등수 뱃지
              Container(
                width: 32,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _rankColor(tier.rank).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${tier.rank}등',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _rankColor(tier.rank)),
                ),
              ),
              const SizedBox(width: 8),
              // 상금
              SizedBox(
                width: 70,
                child: Text(
                  tier.prizeText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                    color: isHighlight ? AppColors.error : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              // 잔여
              SizedBox(
                width: 70,
                child: Text(
                  '${_formatNumber(tier.remaining)}/${_formatNumber(tier.total)}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              // 확률
              Expanded(
                child: Text(
                  prob > 0 ? '1/${_formatNumber((1 / prob).round())}' : '-',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 잔여 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: remainRatio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(_rankColor(tier.rank).withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFE53935);
      case 2: return const Color(0xFFFB8C00);
      case 3: return const Color(0xFF43A047);
      case 4: return AppColors.primary;
      default: return AppColors.grey500;
    }
  }

  String _formatDate(String dt) {
    if (dt.length >= 10) return dt.substring(0, 10);
    return dt;
  }

  String _formatNumber(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}억';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(n >= 1000000 ? 0 : 1)}만';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}천';
    return n.toString();
  }
}
