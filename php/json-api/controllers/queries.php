<?php

class JSON_API_Queries_Controller {

  public function general() {
    global $json_api;    
    $request = array();
    
    if($json_api->query->tags) {
      $request['tag'] = $json_api->query->tags;
    }
    
    if ($json_api->query->search) {
      $request['s'] = $json_api->query->search;
    }

    if ($json_api->query->category) {
      $request['category_name'] = $json_api->query->category;
    }
    
    $posts = $json_api->introspector->get_posts($request);
    return $this->posts_result($posts);
  }
  
  
  protected function posts_result($posts) {
    global $wp_query;
    return array(
      'count' => count($posts),
      'count_total' => (int) $wp_query->found_posts,
      'pages' => $wp_query->max_num_pages,
      'posts' => $posts
    );
  }

}

?>