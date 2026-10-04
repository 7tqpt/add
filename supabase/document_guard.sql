-- ============================================================================
--  حارسُ مستندات التوثيق — المزوّدُ يرفع، والإدارةُ وحدها تعتمد
--
--  شغّله بعد roles.sql. آمنٌ عند التكرار.
--
--  **كشفه فحصٌ أمنيّ:** سياسةُ الرفع (`documents_owner_upload`) تسأل عن
--  `provider_id` وحدَه، فكان المزوّدُ يُدخل صفَّه كما يشاء:
--
--    · بحالة **`approved`** — فيتفعّل زرُّ «توثيق» في اللوحة
--      (`ProviderDetail.tsx`: `allApproved`) قبل أن يراجع أحدٌ شيئاً.
--    · وبمسارٍ في **مجلّد غيره** — واللوحةُ تُصدر الرابطَ بصلاحية المسؤول،
--      فتعرض هويّةَ مزوّدٍ آخر كأنّها هويّتُه.
--
--  فيُفرض هنا ما لا تقدر السياسةُ عليه: الحالةُ «قيد المراجعة»، والمسارُ في
--  مجلّد صاحبه — كما يرفع التطبيقُ (`api.dart`: `'$providerId/…'`).
-- ============================================================================

begin;

create or replace function public.guard_provider_document()
returns trigger language plpgsql set search_path = public as $$
begin
  -- المراجِع: يقبل ويرفض ويكتب ملاحظته.
  if public.can_write_area('directory') then
    return new;
  end if;

  new.status      := 'pending';
  new.reviewed_at := null;
  new.note        := '';

  if new.file_url <> ''
     and (left(new.file_url, 37) <> new.provider_id::text || '/'
          or position('..' in new.file_url) > 0) then
    raise exception 'المستندُ خارجَ مجلّدك.' using errcode = '42501';
  end if;

  return new;
end $$;

drop trigger if exists guard_provider_document on public.provider_documents;
create trigger guard_provider_document
  before insert or update on public.provider_documents
  for each row execute function public.guard_provider_document();

commit;
