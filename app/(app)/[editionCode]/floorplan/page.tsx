import { redirect } from "next/navigation";

/** The floorplan placeholder became the Halls & locations page. */
export default async function FloorplanRedirect({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const { editionCode } = await params;
  redirect(`/${editionCode}/halls`);
}
