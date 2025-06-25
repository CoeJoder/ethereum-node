type ListState = boolean[];
type PageState = { lists: Record<string, ListState> };
type ProgressState = Record<string, PageState>;

/**
 * Tracks progress on guide pages by which checkboxes are ticked and whether
 * there is any progress on the current page.  State is saved to the browser’s
 * localstorage.
 *
 * The implementation is a fixed-up, simplified version of the ProgressStore class in
 * the Astro Docs "Build a Blog" tutorial.
 *
 * See: https://github.com/withastro/docs/blob/main/src/components/tutorial/ProgressStore.ts
 *
 * --------------
 *
 * Features removed:
 * page-done state, page-done subscriptions, sublists, i18n
 *
 * Features added:
 * any-progress subscriptions
 *
 * Improvements:
 * no unnecessary storage of derived state, better page key encapsulation,
 * better OOP in general
 */
class ProgressStore {
  private static readonly key = "ethereum-node-progress";

  private readonly state = ProgressStore.load();
  private readonly subscribers = new Map<(b: boolean) => void, string>();

  /**
   * Initialize the stored state of a Checklist.
   *
   * @param listName The Checklist name
   * @param length The number of list items
   */
  public initializeList(listName: string, length: number): void {
    if (!this.currentPageState.lists[listName]) {
      this.currentPageState.lists[listName] = Array.from(
        { length },
        () => false
      );
    }
    this.store();
  }

  /**
   * Get the stored state of a checkbox.
   *
   * @param listName The Checklist name
   * @param index The list item index
   * @returns Whether checked or not
   */
  public getListItem(listName: string, index: number): boolean {
    return this.currentPageState.lists[listName][index];
  }

  /**
   * Set the stored state of a checkbox.
   *
   * @param listName The Checklist name
   * @param index The list item index
   * @param value Whether checked or not
   */
  public setListItem(listName: string, index: number, value: boolean): void {
    this.currentPageState.lists[listName][index] = value;
    this.store();
  }

  /**
   * Reset all progress on the current page.
   */
  public resetProgress() {
    Object.entries(this.currentPageState.lists).forEach(([name, state]) => {
      const length = state.length;
      this.currentPageState.lists[name] = Array.from({ length }, () => false);
    });
    this.store();
  }

  /**
   * Subscribe to progress updates for the current page.
   *
   * @param callback The callback for progress updates, passed `true` if there
   * is any progress on the current page, `false` otherwise
   * @returns The unsubscribe function
   */
  public subscribeAnyProgress(
    callback: (hasAnyProgress: boolean) => void
  ): () => void {
    this.subscribers.set(callback, this.currentPageKey);
    callback(this.hasAnyProgressOnPage(this.currentPageKey));
    return () => void this.subscribers.delete(callback);
  }

  private notifySubscribers() {
    for (const [callback, path] of this.subscribers.entries()) {
      callback(this.hasAnyProgressOnPage(path));
    }
  }

  private hasAnyProgressOnPage(pageKey: string): boolean {
    const state = this.state[pageKey];
    return Object.values(state.lists).some(
      ProgressStore.doesListHaveAnyProgress
    );
  }

  private static doesListHaveAnyProgress(list: ListState): boolean {
    return list.some((i) => i);
  }

  private store(): void {
    this.notifySubscribers();
    try {
      localStorage.setItem(ProgressStore.key, JSON.stringify(this.state));
    } catch {
      /* might be incognito mode, no biggie */
    }
  }

  private static load(): ProgressState {
    try {
      const state = JSON.parse(localStorage.getItem(ProgressStore.key) || "{}");
      if (ProgressStore.validate(state)) return state;
    } catch {
      /* assume no stored state */
    }
    return {};
  }

  private static validate(state: unknown): state is ProgressState {
    return (
      !!state &&
      typeof state === "object" &&
      Object.values(state).every((val) => !!val.lists)
    );
  }

  private get currentPageState(): PageState {
    if (!(this.currentPageKey in this.state)) {
      this.state[this.currentPageKey] = { lists: {} };
    }
    return this.state[this.currentPageKey];
  }

  private get currentPageKey() {
    return window.location.pathname;
  }
}

export default new ProgressStore();
