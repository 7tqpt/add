import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AppLayout } from '@/components/layout/AppLayout'
import { AreaGuard } from '@/components/layout/AreaGuard'
import { NoAccess } from '@/components/layout/NoAccess'
import { LoadingBlock } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { AuditPage } from '@/pages/Audit'
import { BookingDetailPage } from '@/pages/BookingDetail'
import { BookingsPage } from '@/pages/Bookings'
import { CatalogPage } from '@/pages/Catalog'
import { DashboardPage } from '@/pages/Dashboard'
import { DisputeDetailPage } from '@/pages/DisputeDetail'
import { DisputesPage } from '@/pages/Disputes'
import { LoginPage } from '@/pages/Login'
import { NotFoundPage } from '@/pages/NotFound'
import { NotificationsPage } from '@/pages/Notifications'
import { PaymentsPage } from '@/pages/Payments'
import { PlanDetailPage } from '@/pages/PlanDetail'
import { PlansPage } from '@/pages/Plans'
import { CouponsPage } from '@/pages/Coupons'
import { PromotionsPage } from '@/pages/Promotions'
import { ProviderDetailPage } from '@/pages/ProviderDetail'
import { ProvidersPage } from '@/pages/Providers'
import { ReviewsPage } from '@/pages/Reviews'
import { SettingsPage } from '@/pages/Settings'
import { SettlementsPage } from '@/pages/Settlements'
import { SupportPage } from '@/pages/Support'
import { SupportTicketPage } from '@/pages/SupportTicket'
import { UserDetailPage } from '@/pages/UserDetail'
import { UsersPage } from '@/pages/Users'
import { VersionsPage } from '@/pages/Versions'

function RequireAuth() {
  const { user, role, loading, roleResolved } = useAuth()
  const location = useLocation()

  if (loading) return <LoadingBlock label="جارٍ التحقق من الجلسة…" />
  // `state` carries the attempted URL so login can return there.
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (!roleResolved) return <LoadingBlock label="جارٍ التحقق من الصلاحية…" />

  /**
   * موثَّق الهوية لا يعني مخوَّلاً. حساب بلا صف في `admins` — عميل أو مقدّم
   * خدمة سجّل بحساب تطبيقه، أو مسؤول لم يُمنح الدور بعد — كانت RLS تمنعه من
   * كل شيء فيرى لوحةً فارغة يظنّها عطلاً. الرفض الصريح أصدق، وهو نفسه الحدّ
   * الذي يفصل التطبيقين عن اللوحة.
   */
  if (role === null) return <NoAccess />

  return <AppLayout />
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        {/* حارس المجال داخل التخطيط: القائمة تبقى ظاهرة فيعرف المستخدم أين هو. */}
        <Route element={<AreaGuard />}>
          <Route path="/" element={<DashboardPage />} />

          <Route path="/bookings" element={<BookingsPage />} />
          <Route path="/bookings/:id" element={<BookingDetailPage />} />
          <Route path="/plans" element={<PlansPage />} />
          <Route path="/plans/:id" element={<PlanDetailPage />} />

          <Route path="/users" element={<UsersPage />} />
          <Route path="/users/:id" element={<UserDetailPage />} />
          <Route path="/providers" element={<ProvidersPage />} />
          <Route path="/providers/:id" element={<ProviderDetailPage />} />
          <Route path="/catalog" element={<CatalogPage />} />

          <Route path="/payments" element={<PaymentsPage />} />
          <Route path="/settlements" element={<SettlementsPage />} />
          <Route path="/promotions" element={<PromotionsPage />} />
          <Route path="/coupons" element={<CouponsPage />} />

          <Route path="/support" element={<SupportPage />} />
          <Route path="/support/:id" element={<SupportTicketPage />} />
          <Route path="/disputes" element={<DisputesPage />} />
          <Route path="/disputes/:id" element={<DisputeDetailPage />} />
          <Route path="/reviews" element={<ReviewsPage />} />

          <Route path="/notifications" element={<NotificationsPage />} />
          <Route path="/versions" element={<VersionsPage />} />
          <Route path="/audit" element={<AuditPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Route>
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
