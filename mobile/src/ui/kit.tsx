import type { ReactNode } from 'react'
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInputProps,
} from 'react-native'
import { colors, radius, space, text } from '@/lib/theme'

/**
 * عناصر الواجهة المشتركة.
 *
 * كلها تكتب النصّ العربي بمحاذاة اليمين صراحةً: React Native لا يقلب التخطيط
 * تلقائياً كما يفعل المتصفّح مع `dir="rtl"`، فالاتّكال على الافتراضي يترك
 * العناوين والقيم على اليسار في نصف الشاشات.
 */

export function Screen({ children }: { children: ReactNode }) {
  return <View style={styles.screen}>{children}</View>
}

export function Card({ children, style }: { children: ReactNode; style?: object }) {
  return <View style={[styles.card, style]}>{children}</View>
}

export function Title({ children }: { children: ReactNode }) {
  return <Text style={[text.title, styles.rtl]}>{children}</Text>
}

export function Heading({ children }: { children: ReactNode }) {
  return <Text style={[text.heading, styles.rtl]}>{children}</Text>
}

export function Body({ children, numberOfLines }: { children: ReactNode; numberOfLines?: number }) {
  return (
    <Text style={[text.body, styles.rtl]} numberOfLines={numberOfLines}>
      {children}
    </Text>
  )
}

export function Muted({ children }: { children: ReactNode }) {
  return <Text style={[text.small, styles.rtl]}>{children}</Text>
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  disabled,
  busy,
}: {
  label: string
  onPress: () => void
  variant?: 'primary' | 'secondary' | 'ghost'
  disabled?: boolean
  busy?: boolean
}) {
  const isPrimary = variant === 'primary'
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      disabled={disabled || busy}
      style={({ pressed }) => [
        styles.button,
        isPrimary && styles.buttonPrimary,
        variant === 'secondary' && styles.buttonSecondary,
        variant === 'ghost' && styles.buttonGhost,
        (disabled || busy) && styles.buttonDisabled,
        pressed && styles.buttonPressed,
      ]}
    >
      {busy ? (
        <ActivityIndicator size="small" color={isPrimary ? colors.accentInk : colors.ink} />
      ) : (
        <Text
          style={[
            styles.buttonLabel,
            isPrimary ? styles.buttonLabelPrimary : styles.buttonLabelPlain,
          ]}
        >
          {label}
        </Text>
      )}
    </Pressable>
  )
}

export function Input({ label, hint, ...rest }: TextInputProps & { label: string; hint?: string }) {
  return (
    <View style={styles.field}>
      <Text style={[text.small, styles.rtl, styles.label]}>{label}</Text>
      <TextInput
        placeholderTextColor={colors.muted}
        // النصّ اللاتيني (البريد، الرمز) يبقى من اليسار وإلا تبعثرت رموزه.
        style={[styles.input, rest.textAlign ? null : styles.rtl]}
        {...rest}
      />
      {hint ? <Text style={[text.tiny, styles.rtl]}>{hint}</Text> : null}
    </View>
  )
}

const TONE_COLOR = {
  good: colors.good,
  warning: colors.warning,
  critical: colors.critical,
  neutral: colors.muted,
} as const

export function Badge({
  label,
  tone = 'neutral',
}: {
  label: string
  tone?: keyof typeof TONE_COLOR
}) {
  const tint = TONE_COLOR[tone]
  return (
    <View style={[styles.badge, { borderColor: tint }]}>
      <Text style={[styles.badgeText, { color: tint }]}>{label}</Text>
    </View>
  )
}

export function Loading({ label = 'جارٍ التحميل…' }: { label?: string }) {
  return (
    <View style={styles.center}>
      <ActivityIndicator color={colors.accent} />
      <Text style={[text.small, { marginTop: space.sm }]}>{label}</Text>
    </View>
  )
}

export function Empty({ title, description }: { title: string; description?: string }) {
  return (
    <View style={styles.center}>
      <Text style={[text.heading, styles.centerText]}>{title}</Text>
      {description ? <Text style={[text.small, styles.centerText]}>{description}</Text> : null}
    </View>
  )
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <View style={styles.center}>
      <Text style={[text.body, styles.centerText, { color: colors.critical }]}>{message}</Text>
      {onRetry ? (
        <View style={{ marginTop: space.md }}>
          <Button label="إعادة المحاولة" variant="secondary" onPress={onRetry} />
        </View>
      ) : null}
    </View>
  )
}

/** سطر «اسم: قيمة» بمحاذاة طرفَي البطاقة. */
export function Row({ label, value }: { label: string; value: ReactNode }) {
  return (
    <View style={styles.row}>
      <Text style={text.small}>{label}</Text>
      <Text style={[text.body, { color: colors.ink, fontWeight: '600' }]}>{value}</Text>
    </View>
  )
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.page },
  rtl: { textAlign: 'right', writingDirection: 'rtl' },
  centerText: { textAlign: 'center' },
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.hairline,
    padding: space.lg,
    gap: space.sm,
  },
  button: {
    minHeight: 46,
    borderRadius: radius.sm,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: space.lg,
  },
  buttonPrimary: { backgroundColor: colors.accent },
  buttonSecondary: {
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.hairline,
  },
  buttonGhost: { backgroundColor: 'transparent' },
  buttonDisabled: { opacity: 0.5 },
  buttonPressed: { opacity: 0.85 },
  buttonLabel: { fontSize: 15, fontWeight: '600' },
  buttonLabelPrimary: { color: colors.accentInk },
  buttonLabelPlain: { color: colors.ink },
  field: { gap: space.xs },
  label: { color: colors.ink2 },
  input: {
    minHeight: 46,
    borderWidth: 1,
    borderColor: colors.hairline,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    paddingHorizontal: space.md,
    fontSize: 15,
    color: colors.ink,
  },
  badge: {
    borderWidth: 1,
    borderRadius: radius.pill,
    paddingHorizontal: space.sm,
    paddingVertical: 2,
    alignSelf: 'flex-start',
  },
  badgeText: { fontSize: 11, fontWeight: '600' },
  center: { padding: space.xl, alignItems: 'center', justifyContent: 'center', gap: space.xs },
  row: {
    flexDirection: 'row-reverse',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: space.md,
    paddingVertical: space.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.hairline,
  },
})

export { styles as kit }
