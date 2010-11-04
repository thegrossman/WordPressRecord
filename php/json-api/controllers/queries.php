<?php

class JSON_API_Queries_Controller {

  // Retrieve posts based on provided tags
  public function get_posts_by_tags() {
    global $json_api;
    
    $query = array();
    
    if($json_api->query->tags) {
      $query['tag'] = $json_api->query->tags;
    } else {
      $json_api->error("Include 'tags' var in your request.");
    }
    
    if ($json_api->query->search) {
      $query['s'] = $json_api->query->search;
    }
    
    $posts = $json_api->introspector->get_posts($query);
    
    return array(
      'count_total' => count($posts),
      'posts' => $posts
    );
  }  

}

?>