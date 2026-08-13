import { useCallback } from 'react'
import { FlatList, RefreshControl, Text, View } from 'react-native'
import { Badge, Card, Empty, ErrorNote, Loading, Row, Screen } from '@/ui/kit'
import { listMyPlans } from '@/lib/api'
import { useAsync } from '@/lib/useAsync'
import { formatDate, formatMoney } from '@/lib/format'
import { colors, space, text } from '@/lib/theme'

const PLAN_STATUS_LABEL = {
  planning: 'قيد التجهيز',
  confirmed: 'مؤكدة',
  completed: 'تمّت',
  cancelled: 'ملغاة',
} as const

export default function Plan() {
  const load = useCallback(() => listMyPlans(), [])
  const plans = useAsync(load, [])

  if (plans.loading) return <Screen><Loading /></Screen>
  if (plans.error) return <Screen><ErrorNote message={plans.error} onRetry={plans.reload} /></Screen>

  const rows = plans.data ?? []
  if (rows.length === 0) {
    return (
      <Screen>
        <Empty
          title="لا خطة بعد"
          description="خطة العرس تجمع حجوزاتك في مكان واحد وتحسب لك المتبقّي من ميزانيتك."
        />
      </Screen>
    )
  }

  return (
    <Screen>
      <FlatList
        data={rows}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ padding: space.lg, gap: space.md }}
        refreshControl={
          <RefreshControl refreshing={false} onRefresh={plans.reload} tintColor={colors.accent} />
        }
        renderItem={({ item }) => {
          const spent = item.budget > 0 ? Math.min(1, item.total_cost / item.budget) : 0
          const over = item.total_cost > item.budget && item.budget > 0
          return (
            <Card>
              <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
                <Text style={[text.heading, { flex: 1, textAlign: 'right' }]}>{item.title}</Text>
                <Badge
                  label={PLAN_STATUS_LABEL[item.status]}
                  tone={item.status === 'cancelled' ? 'neutral' : 'good'}
                />
              </View>

              <Text style={[text.small, { textAlign: 'right' }]}>
                {formatDate(item.wedding_date)} · {item.governorate} · {item.guests_count} ضيف
              </Text>

              {/* شريط الميزانية: النسبة تُقرأ بلمحة، والرقم تحته للدقّة. */}
              <View style={styles.track}>
                <View
                  style={[
                    styles.fill,
                    { width: `${spent * 100}%`, backgroundColor: over ? colors.critical : colors.accent },
                  ]}
                />
              </View>

              <Row label="الميزانية" value={formatMoney(item.budget)} />
              <Row label="إجمالي الحجوزات" value={formatMoney(item.total_cost)} />
              <Row label="المدفوع" value={formatMoney(item.paid_amount)} />
              <Row label="المتبقّي عليك" value={formatMoney(item.remaining_amount)} />

              {over ? (
                <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>
                  تجاوزت الميزانية بـ {formatMoney(item.total_cost - item.budget)}.
                </Text>
              ) : null}
            </Card>
          )
        }}
      />
    </Screen>
  )
}

const styles = {
  track: {
    height: 8,
    borderRadius: 999,
    backgroundColor: colors.surface2,
    overflow: 'hidden' as const,
  },
  fill: { height: 8, borderRadius: 999 },
}
