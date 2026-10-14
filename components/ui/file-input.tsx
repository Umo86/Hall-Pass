"use client";

import { useState } from "react";
import { Paperclip } from "lucide-react";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * A file picker that looks like the rest of the app: a "Choose file…"
 * button and the chosen file's name. The real <input type="file"> stays in
 * the form (visually hidden), so FormData and `name` work as before.
 */
export function FileInput({
  id,
  name,
  accept,
  multiple,
  required,
  disabled,
  buttonLabel = "Choose file…",
  onFileChange,
  className,
  inputRef,
}: {
  id?: string;
  name?: string;
  accept?: string;
  multiple?: boolean;
  required?: boolean;
  disabled?: boolean;
  buttonLabel?: string;
  onFileChange?: (files: FileList | null) => void;
  className?: string;
  inputRef?: React.Ref<HTMLInputElement>;
}) {
  const [label, setLabel] = useState<string | null>(null);
  return (
    <div className={cn("flex min-w-0 flex-wrap items-center gap-2", className)}>
      <label
        className={cn(
          buttonVariants({ variant: "outline", size: "sm" }),
          "has-[:focus-visible]:ring-ring cursor-pointer has-[:focus-visible]:ring-2",
          disabled && "pointer-events-none opacity-50",
        )}
      >
        <Paperclip aria-hidden />
        {buttonLabel}
        <input
          ref={inputRef}
          id={id}
          name={name}
          type="file"
          accept={accept}
          multiple={multiple}
          required={required}
          disabled={disabled}
          className="sr-only"
          onChange={(e) => {
            const files = e.currentTarget.files;
            setLabel(
              !files || files.length === 0
                ? null
                : files.length === 1
                  ? files[0].name
                  : `${files.length} files`,
            );
            onFileChange?.(files);
          }}
        />
      </label>
      <span className="text-muted-foreground min-w-0 truncate text-sm">
        {label ?? "No file chosen"}
      </span>
    </div>
  );
}
