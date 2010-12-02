<?php

class JSON_API_Queries_Controller {

  public function general() {
    global $json_api;
    
    $query = array();
    
    if($json_api->query->tags) {
      $query['tag'] = $json_api->query->tags;
    }
    
    if ($json_api->query->search) {
      $query['s'] = $json_api->query->search;
    }

    if ($json_api->query->category) {
      $query['category_name'] = $json_api->query->category;
    }
    
    $posts = $json_api->introspector->get_posts($query);
    
    return array(
      'count_total' => count($posts),
      'posts' => $posts
    );
  }  

}

?>