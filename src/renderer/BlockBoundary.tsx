"use client";

import { Component, type ReactNode } from "react";
import { UI } from "./ui-strings";

/** One failing block must not take the page down. Content is validated, so this guards runtime faults. */
export class BlockBoundary extends Component<{ blockId: string; blockType: string; children: ReactNode }, { failed: boolean }> {
  override state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  override componentDidCatch(error: unknown) {
    console.error(`Block '${this.props.blockId}' (${this.props.blockType}) failed to render`, error);
  }
  override render() {
    return this.state.failed ? <p role="status">{UI.blockFailed}</p> : this.props.children;
  }
}
