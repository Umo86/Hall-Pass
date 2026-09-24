import { redirect } from "next/navigation";

/** /BIRM27 on its own lands on the edition dashboard. */
export default async function EditionIndex({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const { editionCode } = await params;
  redirect(`/${editionCode}/dashboard`);
}
