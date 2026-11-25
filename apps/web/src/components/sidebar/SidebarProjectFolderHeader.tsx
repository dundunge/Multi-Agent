import type { EnvironmentThreadShell } from "@t3tools/client-runtime/state/models";
import { scopedThreadKey, scopeThreadRef } from "@t3tools/client-runtime/environment";
import type { ContextMenuSource } from "@t3tools/contracts";
import { ChevronRightIcon, FolderIcon, FolderOpenIcon, PinIcon, PlusIcon } from "lucide-react";
import { msg, T, useGT, useMessages, Var } from "gt-react";
import { memo } from "react";

import { cn } from "~/lib/utils";
import { contextMenuSourceOf } from "../../contextMenuSource";
import type { SidebarProjectSnapshot } from "../../sidebarProjectGrouping";
import { useUiStateStore } from "../../uiStateStore";
import { resolveSidebarFolderDot, resolveThreadLastVisitedAt } from "../Sidebar.logic";
import { Button } from "../ui/button";
import { Tooltip, TooltipPopup, TooltipTrigger } from "../ui/tooltip";

const FOLDER_DOT_CLASS_NAME = {
  attention: "bg-warning",
  failed: "bg-error",
  unread: "bg-success",
  working: "bg-info",
} as const;

const FOLDER_DOT_LABEL = {
  attention: msg(", needs you", { $context: "project folder status, read after its name" }),
  failed: msg(", failed", { $context: "project folder status, read after its name" }),
  unread: msg(", done", { $context: "project folder status, read after its name" }),
  working: msg(", working", { $context: "project folder status, read after its name" }),
} as const;

/** The folder's sidebar tree row; its thread rows name it as their parent. */
export function sidebarFolderRowId(projectKey: string) {
  return `folder:${projectKey}`;
}

/**
 * A project folder in the boring sidebar. It reads like a shelf header: a trailing
 * count and chevron, with the count and a status dot only while it is closed, so a
 * closed folder still says when a hidden thread needs you.
 */
export const SidebarProjectFolderHeader = memo(function SidebarProjectFolderHeader(props: {
  group: SidebarProjectSnapshot;
  collapsed: boolean;
  threadCount?: number | undefined;
  hiddenThreads: readonly EnvironmentThreadShell[];
  onToggle: (group: SidebarProjectSnapshot) => void;
  onNewThread: (group: SidebarProjectSnapshot) => void;
  onContextMenu: (
    group: SidebarProjectSnapshot,
    position: { x: number; y: number },
    source: ContextMenuSource,
  ) => void;
}) {
  const gt = useGT();
  const m = useMessages();
  const { group, collapsed, hiddenThreads } = props;
  const totalThreads = props.threadCount ?? hiddenThreads.length;
  const hasThreads = totalThreads > 0;
  const FolderGlyph = !collapsed ? FolderOpenIcon : FolderIcon;
  const rowId = sidebarFolderRowId(group.projectKey);
  const localLastVisitedAtById = useUiStateStore((state) => state.threadLastVisitedAtById);
  const dot = collapsed
    ? resolveSidebarFolderDot(
        hiddenThreads.map((thread) => ({
          ...thread,
          lastVisitedAt: resolveThreadLastVisitedAt(
            thread.lastVisitedAt,
            localLastVisitedAtById[
              scopedThreadKey(scopeThreadRef(thread.environmentId, thread.id))
            ],
          ),
        })),
      )
    : null;
  return (
    <li
      data-testid="sidebar-project-folder"
      className={cn(
        "group/project-folder relative mt-0.5 list-none first:mt-0",
        !collapsed && hasThreads && "mt-1",
      )}
    >
      <button
        type="button"
        data-sidebar-row={rowId}
        aria-expanded={!collapsed}
        onClick={() => props.onToggle(group)}
        onContextMenu={(event) => {
          event.preventDefault();
          props.onContextMenu(
            group,
            { x: event.clientX, y: event.clientY },
            contextMenuSourceOf(event),
          );
        }}
        className="flex h-7.5 w-full cursor-pointer items-center gap-2 rounded-(--control-radius) px-2 text-left outline-none hover:bg-sidebar-row-hover focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
      >
        <FolderGlyph
          aria-hidden
          className={cn(
            "size-4 shrink-0 transition-colors",
            !collapsed && hasThreads
              ? "text-sidebar-foreground/85"
              : "text-sidebar-muted-foreground",
          )}
        />
        <span
          className={cn(
            "min-w-0 flex-1 truncate text-sm transition-colors",
            !collapsed && hasThreads
              ? "font-medium text-sidebar-foreground"
              : "font-normal text-sidebar-foreground/85 group-hover/project-folder:text-sidebar-foreground",
          )}
        >
          {group.displayName}
        </span>
        {group.pinned ? (
          <PinIcon
            aria-hidden
            className="size-3 shrink-0 text-sidebar-muted-foreground/55 group-hover/project-folder:invisible"
          />
        ) : null}
        {dot ? (
          <span className={cn("size-1.5 shrink-0 rounded-full", FOLDER_DOT_CLASS_NAME[dot])}>
            <span className="sr-only">{m(FOLDER_DOT_LABEL[dot])}</span>
          </span>
        ) : null}
        {collapsed && hiddenThreads.length > 0 ? (
          <span className="shrink-0 text-2xs tabular-nums text-sidebar-muted-foreground/80 group-hover/project-folder:invisible group-has-[[data-sidebar-action-for]:focus]/project-folder:invisible pointer-coarse:invisible">
            {hiddenThreads.length}
          </span>
        ) : null}
        <ChevronRightIcon
          aria-hidden
          className={cn(
            "size-3 shrink-0 text-sidebar-muted-foreground/70 transition-transform",
            !collapsed && "rotate-90",
            !hasThreads && "opacity-35 group-hover/project-folder:opacity-70",
          )}
        />
      </button>
      {/* Sits over the count, which hides on hover or focus, and left of the chevron. */}
      <span className="absolute inset-y-0 right-5.5 flex items-center opacity-0 focus-within:opacity-100 group-hover/project-folder:opacity-100 pointer-coarse:opacity-100">
        <Tooltip>
          <TooltipTrigger
            render={
              <Button
                data-sidebar-action-for={rowId}
                size="icon-xs"
                variant="ghost-muted"
                aria-label={gt("New thread in {project}", { project: group.displayName })}
                onClick={() => props.onNewThread(group)}
              />
            }
          >
            <PlusIcon aria-hidden className="size-3.5" />
          </TooltipTrigger>
          <TooltipPopup>
            <T>
              New thread in <Var>{group.displayName}</Var>
            </T>
          </TooltipPopup>
        </Tooltip>
      </span>
    </li>
  );
});
