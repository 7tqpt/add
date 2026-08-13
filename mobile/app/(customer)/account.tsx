import { ScrollView, Text, View } from 'react-native'
import { useRouter } from 'expo-router'
import { Body, Button, Card, Heading, Row, Screen } from '@/ui/kit'
import { useSession } from '@/lib/session'
import { space, text } from '@/lib/theme'

export default function Account() {
  const { email, providerId, setRole, signOut } = useSession()
  const router = useRouter()

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.md }}>
        <Card>
          <Heading>حسابي</Heading>
          <Row label="البريد" value={email} />
        </Card>

        <Card>
          <Heading>الدعم</Heading>
          <Body>واجهتك مشكلة أو عندك سؤال؟ افتح تذكرة وتصلك ردود الإدارة هنا.</Body>
          <Button label="تذاكر الدعم" variant="secondary" onPress={() => router.push('/support')} />
        </Card>

        <Card>
          <Heading>تقديم الخدمات</Heading>
          {providerId ? (
            <>
              {/*
                الدور اختيار عرضٍ لا هوية: الشخص نفسه قد يحجز لعرس أخيه ويبيع
                خدمة التصوير. فالتبديل هنا لا في التسجيل.
              */}
              <Body>لديك ملف مقدّم خدمة. بدّل العرض لإدارة طلباتك وخدماتك.</Body>
              <Button
                label="التبديل إلى وضع مقدّم الخدمة"
                onPress={() => {
                  setRole('provider')
                  router.replace('/(provider)/requests')
                }}
              />
            </>
          ) : (
            <>
              <Body>
                عندك قاعة أو خدمة تقدّمها للأعراس؟ قدّم طلبك، وبعد مراجعة الإدارة لمستنداتك
                تبدأ باستقبال الحجوزات.
              </Body>
              <Button
                label="أريد تقديم خدمة"
                variant="secondary"
                onPress={() => router.push('/become-provider')}
              />
            </>
          )}
        </Card>

        <View style={{ marginTop: space.md }}>
          <Button label="تسجيل الخروج" variant="ghost" onPress={() => void signOut()} />
        </View>

        <Text style={[text.tiny, { textAlign: 'center' }]}>الإصدار 0.1.0</Text>
      </ScrollView>
    </Screen>
  )
}
