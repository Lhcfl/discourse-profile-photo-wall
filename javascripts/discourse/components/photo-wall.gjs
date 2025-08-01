import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
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
    return settings.photowall_tag_name.split("|").filter((x) => x);
  }

  get user() {
    return this.args.user;
  }

  get isThisUser() {
    return this.currentUser?.id === this.args.user.id;
  }

  get shouldSeePhotoWall() {
    return this.isThisUser || this.photoList;
  }

  async getPhotoList() {
    try {
      this.loading = true;
      const res = await this.store.findFiltered("topicList", {
        filter: `topics/created-by/${this.user.username_lower}`,
        params:
          this.photoTags.length > 0
            ? {
                tags: this.photoTags,
              }
            : { match_all_tags: true },
      });

      // seems like in new version of Discourse, response structure has changed
      const photoTopics = (res?.topics ?? res?.topic_list?.topics ?? [])
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

      if (photoList.length > 0) {
        this.renderLightBoxAndColumns();
      }
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

  <template>
    {{#if this.shouldSeePhotoWall}}
      <div class="top-section photo-wall">
        <h3>
          {{i18n (themePrefix "photowall.name")}}
          {{#if this.isThisUser}}
            <DButton
              @action={{this.openAddPhotoComposer}}
              @icon="far-pen-to-square"
              class="btn-link btn-small"
            />
          {{/if}}
        </h3>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.photoList}}
            <div id={{this.randomId}} class="cooked photo-wall-cards-container">
              <div class="d-image-grid">
                {{#each this.photoList as |item|}}
                  <p>
                    <div class="lightbox-wrapper">
                      <a
                        class="lightbox"
                        href={{item.image_url}}
                        data-download-href={{item.image_url}}
                        data-topic-id={{item.id}}
                        title={{item.fancy_title}}
                      >
                        <img
                          src={{item.image_url}}
                          srcset={{item.image_url}}
                          alt={{item.fancy_title}}
                          width={{item.image_width}}
                          height={{item.image_height}}
                          loading="lazy"
                        />
                        <div class="meta">
                          {{icon "far-image"}}
                          {{! I don't know how to fix this }}
                          {{! template-lint-disable no-nested-interactive }}
                          <a
                            class="filename"
                            href={{item.url}}
                            onclick={{fn this.routeToTopic item}}
                          >
                            {{item.fancy_title}}
                          </a>
                          <span class="informations">
                            <span>
                              {{#if item.liked}}
                                {{icon "heart"}}
                              {{else}}
                                {{icon "far-heart"}}
                              {{/if}}
                              <span class="hidden">{{i18n
                                  "about.like_count"
                                }}</span>
                              {{item.like_count}}
                            </span>
                            <span>
                              {{icon "comment"}}
                              <span class="hidden">{{i18n
                                  "about.post_count"
                                }}</span>
                              {{item.reply_count}}
                            </span>
                          </span>
                          {{icon "discourse-expand"}}
                        </div>
                      </a>
                    </div>
                  </p>
                {{/each}}
              </div>
            </div>
          {{else}}
            {{i18n (themePrefix "photowall.nothing")}}
          {{/if}}
        </ConditionalLoadingSpinner>
      </div>
    {{/if}}
  </template>
}
