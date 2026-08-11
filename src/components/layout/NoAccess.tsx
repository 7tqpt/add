import { useState } from 'react'
import { ShieldOff } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Spinner } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'

/**
 * حساب صحيح بلا صلاحية إدارة.
 *
 * تظهر لحالتين: مسؤول أُنشئ حسابه ولم يُسجَّل في جدول `admins` بعد، وعميل أو
 * مقدّم خدمة حاول الدخول بحساب تطبيقه. الرسالة واحدة عمداً — لا تكشف للثاني
 * ما ينقصه ليصير الأول.
 */
export function NoAccess() {
  const { user, signOut } = useAuth()
  const [busy, setBusy] = useState(false)

  return (
    <div className="flex min-h-full items-center justify-center bg-page p-6">
      <Card className="w-full max-w-md p-6 text-center sm:p-8">
        <span
          aria-hidden
          className="mx-auto flex h-12 w-12 items-center justify-center rounded-full"
          style={{ background: 'color-mix(in oklab, var(--critical) 12%, transparent)' }}
        >
          <ShieldOff size={22} style={{ color: 'var(--critical)' }} />
        </span>

        <h1 className="mt-4 text-base font-semibold text-ink">لا تملك صلاحية الدخول</h1>

        <p className="mt-2 text-sm leading-7 text-ink-2">
          الحساب <span dir="ltr" className="font-medium">{user?.email}</span> موثَّق، لكنه ليس
          حساب إدارة. لوحة التحكم مخصّصة لفريق المنصة وحده.
        </p>

        <p className="mt-3 text-xs leading-6 text-muted">
          إن كنت مسؤولاً ولم تُمنح الصلاحية بعد، فالخطوة الناقصة هي إضافة حسابك إلى جدول
          المسؤولين في قاعدة البيانات.
        </p>

        <Button
          variant="secondary"
          className="mt-5 w-full"
          disabled={busy}
          onClick={async () => {
            setBusy(true)
            try {
              await signOut()
            } finally {
              setBusy(false)
            }
          }}
        >
          {busy ? <Spinner /> : null}
          تسجيل الخروج
        </Button>
      </Card>
    </div>
  )
}
