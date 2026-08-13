import { Redirect } from 'expo-router'
import { Loading, Screen } from '@/ui/kit'
import { useSession } from '@/lib/session'

/**
 * بوّابة الإقلاع: تقرّر أين يبدأ المستخدم.
 *
 * الترتيب مقصود — جلسة، ثم ملف، ثم دور. من لا جلسة له لا معنى لسؤاله عن دوره،
 * ومن لا ملف له لا يستطيع الحجز ولو كان مسجّل الدخول.
 */
export default function Index() {
  const { userId, appUserId, role, loading, needsProfile } = useSession()

  if (loading) {
    return (
      <Screen>
        <Loading label="جارٍ التحقق…" />
      </Screen>
    )
  }

  if (!userId) return <Redirect href="/sign-in" />
  if (needsProfile || !appUserId) return <Redirect href="/onboarding" />
  return <Redirect href={role === 'provider' ? '/(provider)/requests' : '/(customer)/explore'} />
}
