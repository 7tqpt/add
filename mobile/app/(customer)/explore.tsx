import { useCallback, useState } from 'react'
import { FlatList, Pressable, RefreshControl, Text, TextInput, View } from 'react-native'
import { Link } from 'expo-router'
import { Badge, Card, Empty, ErrorNote, Loading, Screen } from '@/ui/kit'
import { listCategories, listServices } from '@/lib/api'
import { useAsync } from '@/lib/useAsync'
import { formatMoney } from '@/lib/format'
import { colors, radius, space, text } from '@/lib/theme'
import type { Service } from '@/lib/types'

export default function Explore() {
  const [search, setSearch] = useState('')
  const [applied, setApplied] = useState('')
  const [categoryId, setCategoryId] = useState<string | null>(null)

  const loadCategories = useCallback(() => listCategories(), [])
  const categories = useAsync(loadCategories, [])

  const loadServices = useCallback(
    () => listServices({ search: applied, categoryId }),
    [applied, categoryId],
  )
  const services = useAsync(loadServices, [applied, categoryId])

  return (
    <Screen>
      <View style={{ padding: space.lg, paddingBottom: space.sm, gap: space.md }}>
        <TextInput
          value={search}
          onChangeText={setSearch}
          // البحث عند الإرسال لا عند كل حرف: كل ضغطة زرّ طلبٌ للشبكة، وشبكة
          // الجوال هنا ليست دائماً سخيّة.
          onSubmitEditing={() => setApplied(search)}
          returnKeyType="search"
          placeholder="ابحث عن قاعة، مصوّر، طبّاخ…"
          placeholderTextColor={colors.muted}
          style={styles.search}
        />

        <FlatList
          horizontal
          inverted
          showsHorizontalScrollIndicator={false}
          data={[{ id: 'all', name: 'الكل' }, ...(categories.data ?? [])]}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ gap: space.sm }}
          renderItem={({ item }) => {
            const active = item.id === 'all' ? categoryId === null : categoryId === item.id
            return (
              <Pressable
                onPress={() => setCategoryId(item.id === 'all' ? null : item.id)}
                style={[styles.chip, active && styles.chipActive]}
              >
                <Text style={[styles.chipText, active && styles.chipTextActive]}>{item.name}</Text>
              </Pressable>
            )
          }}
        />
      </View>

      {services.loading ? (
        <Loading />
      ) : services.error ? (
        <ErrorNote message={services.error} onRetry={services.reload} />
      ) : (services.data ?? []).length === 0 ? (
        <Empty title="لا توجد خدمات مطابقة" description="جرّب قسماً آخر أو امسح البحث." />
      ) : (
        <FlatList
          data={services.data ?? []}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ padding: space.lg, paddingTop: 0, gap: space.md }}
          refreshControl={
            <RefreshControl refreshing={false} onRefresh={services.reload} tintColor={colors.accent} />
          }
          renderItem={({ item }) => <ServiceRow service={item} />}
        />
      )}
    </Screen>
  )
}

function ServiceRow({ service }: { service: Service }) {
  return (
    <Link href={{ pathname: '/service/[id]', params: { id: service.id } }} asChild>
      <Pressable>
        <Card>
          <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
            <Text style={[text.heading, { flex: 1, textAlign: 'right' }]} numberOfLines={2}>
              {service.title}
            </Text>
            {service.provider_is_featured ? <Badge label="مميّز" tone="warning" /> : null}
          </View>

          <Text style={[text.small, { textAlign: 'right' }]}>
            {service.provider_name} · {service.category_name} · {service.provider_governorate}
          </Text>

          <View style={styles.priceRow}>
            <Text style={[text.heading, { color: colors.accent }]}>
              {formatMoney(service.price)}
              {service.price_to ? ` – ${formatMoney(service.price_to)}` : ''}
            </Text>
            <Text style={text.tiny}>
              {service.provider_rating > 0
                ? `★ ${service.provider_rating} (${service.provider_reviews_count})`
                : 'جديد'}
            </Text>
          </View>

          <Text style={[text.tiny, { textAlign: 'right' }]}>
            العربون {service.deposit_percent}٪ · {service.unit}
          </Text>
        </Card>
      </Pressable>
    </Link>
  )
}

const styles = {
  search: {
    minHeight: 46,
    borderWidth: 1,
    borderColor: colors.hairline,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    paddingHorizontal: space.md,
    fontSize: 15,
    color: colors.ink,
    textAlign: 'right' as const,
  },
  chip: {
    borderWidth: 1,
    borderColor: colors.hairline,
    backgroundColor: colors.surface,
    borderRadius: radius.pill,
    paddingHorizontal: space.md,
    paddingVertical: space.sm,
  },
  chipActive: { borderColor: colors.accent, backgroundColor: colors.accent },
  chipText: { fontSize: 13, color: colors.ink2 },
  chipTextActive: { color: colors.accentInk, fontWeight: '600' as const },
  priceRow: {
    flexDirection: 'row-reverse' as const,
    justifyContent: 'space-between' as const,
    alignItems: 'center' as const,
  },
}
