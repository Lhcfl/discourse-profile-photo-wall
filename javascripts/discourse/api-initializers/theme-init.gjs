import { apiInitializer } from "discourse/lib/api";
import ProfilePhotoWall from "../components/photo-wall";

export default apiInitializer((api) => {
  api.renderInOutlet("below-user-summary", ProfilePhotoWall);
});
