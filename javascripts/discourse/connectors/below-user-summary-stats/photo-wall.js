import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Columns from "discourse/lib/columns";
import lightbox from "discourse/lib/lightbox";
import { i18n } from "discourse-i18n";

export default class ProfilePhotoWall extends Component {
  @service siteSettings;
  @service currentUser;
  @service store;
  @service router;
  @service composer;
  @service site;

  @tracked loading;
  @tracked photoList;
  @tracked randomId = crypto.randomUUID();

  constructor(...args) {
    super(...args);
    this.getPhotoList();
  }

  get photoTags() {
    return settings.photowall_tag_name.split("|");
  }

  get user() {
    return this.args.outletArgs.user;
  }

  get isThisUser() {
    return this.currentUser?.id === this.args.outletArgs.user.id;
  }

  get shouldSeePhotoWall() {
    return this.isThisUser || this.photoList;
  }

  async getPhotoList() {
    try {
      this.loading = true;
      const res = await this.store.findFiltered("topicList", {
        filter: `topics/created-by/${this.user.username_lower}`,
        params: {
          tags: this.photoTags,
        },
      });
      const photoTopics = (res?.topic_list?.topics ?? [])
        .filter((topic) => topic.image_url)
        .map((x) => [
          x.id,
          {
            ...x,
            url: x.url ?? `/t/${x.id}`,
          },
        ]);
      // 去除重复帖
      const photoList = [...new Map(photoTopics).values()];

      // Load all images
      await Promise.allSettled(
        photoList.map(
          (x) =>
            new Promise((ret, rej) => {
              // 超时直接先拒绝
              setTimeout(rej, 2000);
              const img = new Image();
              img.src = x.image_url;
              img.onload = () => {
                this.loading = false;
                x.img_width = img.width;
                x.img_height = img.height;
                ret();
              };
            })
        )
      );

      this.photoList = photoList;
      this.renderLightBoxAndColumns();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(err);
    } finally {
      this.loading = false;
    }
  }

  async renderLightBoxAndColumns() {
    // process in next tick
    await new Promise((r) => setTimeout(r, 0));

    const elem = document.getElementById(this.randomId);
    lightbox(elem, this.siteSettings);

    const grids = elem.querySelectorAll(".d-image-grid");
    if (!grids.length) {
      return;
    }
    grids.forEach((grid) => {
      const column = new Columns(grid, {
        columns: this.site.mobileView ? 2 : 3,
      });
      return column;
    });
  }

  @action
  openAddPhotoComposer() {
    this.composer.openNewTopic({
      tags: this.photoTags.slice(0, 3).join(","),
      body: i18n(themePrefix("photowall.composer_placeholder")),
    });
  }

  @action
  async routeToTopic(topic, ev) {
    ev.preventDefault();
    ev.stopPropagation();
    await this.router.transitionTo(`/t/${topic.id}`);
    this.getPhotoList();
  }
}
